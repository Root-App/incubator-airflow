from datetime import timedelta, datetime

from airflow.models import DAG, Variable
from airflow.operators.bash_operator import BashOperator

args = {
    'owner': 'airflow',
    'start_date': datetime(2015, 1, 1),
    'email': ['airflow@joinroot.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
}

"""
This dag is used for DAG deployment when running Airflow on ECS.

When running on ECS, we use EFS to mount a shared volume to each host and container that contains DAGs. The EFS
volume and EC2 hosts are running in private subnets with no access from the outside world. This makes pushing DAGs from
CI convoluted, so instead we pull. We may switch to push delivery at some point in the future if the complexity is
warranted.

This DAG expects a variable with a private key that has read access to a private git repo to clone from. This is a 
destructive operation and will delete any DAGs on the EFS volume that are no longer in the repository.
"""

dag = DAG(
    dag_id='deploy_dags',
    schedule_interval=None,
    dagrun_timeout=timedelta(minutes=60),
    default_args=args,
    catchup=False
)
dag.doc_md = __doc__

ROOT_AIRFLOW_PRIVATE_KEY = Variable.get("ROOT_AIRFLOW_DEPLOY_KEY", default_var="")
GIT_REPO = Variable.get("ROOT_AIRFLOW_DAG_REPO", default_var="")
GIT_BRANCH = Variable.get("ROOT_AIRFLOW_DAG_BRANCH", default_var="master")
GIT_SUBDIR = Variable.get("ROOT_AIRFLOW_DAG_SUBDIR", default_var="")

if GIT_REPO:
    REPO_NAME = GIT_REPO.split("/")[-1].replace(".git", "")

    BashOperator(
        dag=dag,
        task_id=f"git_clone_dags",
        env={"ROOT_AIRFLOW_DEPLOY_KEY": ROOT_AIRFLOW_PRIVATE_KEY},
        bash_command=f"""echo "$ROOT_AIRFLOW_DEPLOY_KEY" > /usr/local/airflow/.ssh/root-airflow-deploy \
        && chmod 600 ~/.ssh/root-airflow-deploy \
        && GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/root-airflow-deploy" git clone -b {GIT_BRANCH} {GIT_REPO} \
        && rm -rf  /usr/local/airflow/dags/user_dags/* \
        && cp -r {REPO_NAME}/{GIT_SUBDIR} /usr/local/airflow/dags/user_dags/ \
        && rm -rf {REPO_NAME}
        """
    )
