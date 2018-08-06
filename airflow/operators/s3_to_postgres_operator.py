from contextlib import closing

from smart_open import smart_open

from airflow.hooks.S3_hook import S3Hook
from airflow.hooks.postgres_hook import PostgresHook
from airflow.models import BaseOperator


class S3ToPostgresOperator(BaseOperator):
    template_fields = ('s3_key', 'table_name')

    def __init__(self,
                 postgres_conn_id,
                 s3_bucket,
                 s3_key,
                 s3_conn_id,
                 table_name,
                 *args,
                 **kwargs):
        super().__init__(*args, **kwargs)
        self.table_name = table_name
        self.s3_conn_id = s3_conn_id
        self.s3_key = s3_key
        self.s3_bucket = s3_bucket
        self.postgres_conn_id = postgres_conn_id

    def execute(self, context):
        s3_hook = S3Hook(aws_conn_id=self.s3_conn_id)
        session = s3_hook.get_session()

        with smart_open(f's3://{self.s3_bucket}/{self.s3_key}', 'rb', encoding="utf8", s3_session=session) as f:
            target_hook = PostgresHook(postgres_conn_id=self.postgres_conn_id)
            with closing(target_hook.get_conn()) as conn:
                conn.set_client_encoding("UTF8")
                with closing(conn.cursor()) as cur:
                    cur.copy_expert("COPY {} FROM STDIN WITH CSV HEADER".format(self.table_name), f)
                    conn.commit()
