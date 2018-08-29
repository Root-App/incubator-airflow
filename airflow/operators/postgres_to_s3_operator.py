from contextlib import closing

from smart_open import smart_open

from airflow.hooks.S3_hook import S3Hook
from airflow.hooks.postgres_hook import PostgresHook
from airflow.models import BaseOperator


class PostgresToS3Operator(BaseOperator):
    template_fields = ('sql', 's3_key')
    template_ext = ('.sql',)

    def __init__(self,
                 postgres_conn_id,
                 s3_bucket,
                 s3_key,
                 sql,
                 s3_conn_id,
                 copy_options=tuple(),
                 overwrite_file=False,
                 *args,
                 **kwargs):
        super().__init__(*args, **kwargs)
        self.copy_options = copy_options
        self.overwrite_file = overwrite_file
        self.s3_conn_id = s3_conn_id
        self.sql = sql
        self.s3_key = s3_key
        self.s3_bucket = s3_bucket
        self.postgres_conn_id = postgres_conn_id

    def execute(self, context):
        s3_hook = S3Hook(aws_conn_id=self.s3_conn_id)
        session = s3_hook.get_session()

        if self.copy_options:
            copy_options = "WITH " + " ".join(self.copy_options)
        else:
            copy_options = ""

        with smart_open(f's3://{self.s3_bucket}/{self.s3_key}', 'wb', s3_session=session) as fout:
            src_hook = PostgresHook(postgres_conn_id=self.postgres_conn_id)
            with closing(src_hook.get_conn()) as conn:
                conn.set_client_encoding("UTF8")
                with closing(conn.cursor()) as cur:
                    cur.copy_expert("COPY ({}) TO STDOUT {}".format(self.sql, copy_options), fout)
