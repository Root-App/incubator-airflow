from smart_open import smart_open

from airflow.hooks.S3_hook import S3Hook
from airflow.hooks.http_hook import HttpHook
from airflow.models import BaseOperator


class HttpToS3Operator(BaseOperator):
    template_fields = ('s3_key', 'data')

    def __init__(self,
                 http_conn_id,
                 s3_bucket,
                 s3_key,
                 s3_conn_id,
                 endpoint,
                 data=None,
                 method="POST",
                 request_options=None,
                 overwrite_file=False,
                 *args,
                 **kwargs):
        super().__init__(*args, **kwargs)
        if not request_options:
            request_options = dict()
        if not data:
            data = dict()

        self.method = method
        self.endpoint = endpoint
        self.request_options = request_options
        self.data = data
        self.overwrite_file = overwrite_file
        self.s3_conn_id = s3_conn_id
        self.s3_key = s3_key
        self.s3_bucket = s3_bucket
        self.http_conn_id = http_conn_id

    def execute(self, context):
        s3_hook = S3Hook(aws_conn_id=self.s3_conn_id)
        session = s3_hook.get_session()

        with smart_open(f's3://{self.s3_bucket}/{self.s3_key}', 'wb', s3_session=session) as fout:
            http = HttpHook(method=self.method, http_conn_id=self.http_conn_id)

            self.log.info("Calling HTTP method")

            response = http.run(self.endpoint, self.data, extra_options=self.request_options)

            for line in response:
                fout.write(line)
