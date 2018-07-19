# VERSION 1.9.0-4
# AUTHOR: Matthieu "Puckel_" Roisil
# DESCRIPTION: Basic Airflow container
# BUILD: docker build --rm -t puckel/docker-airflow .
# SOURCE: https://github.com/puckel/docker-airflow

FROM python:3.6.5
#LABEL maintainer="Puckel_" Pulled from

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
#ARG AIRFLOW_VERSION=1.9.0
ARG AIRFLOW_HOME=/usr/local/airflow

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

# grab gosu for easy step-down from root
ENV GOSU_VERSION 1.10
RUN set -x \
	&& wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	&& wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
#	&& export GNUPGHOME="$(mktemp -d)" \
#    && for server in $(shuf -e ha.pool.sks-keyservers.net \
#                                hkp://p80.pool.sks-keyservers.net:80 \
#                                keyserver.ubuntu.com \
#                                hkp://keyserver.ubuntu.com:80 \
#                                pgp.mit.edu) ; do \
#            gpg --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
#        done \
#	&& gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
#	&& rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	&& gosu nobody true

COPY . /airflow

RUN set -ex \
    && buildDeps=' \
        python3-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        build-essential \
        libblas-dev \
        liblapack-dev \
        libpq-dev \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        python3-pip \
        python3-requests \
        mysql-client \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
        git \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && groupadd -g 5014 airflow \
    && useradd -u 5014 -g 5014 -ms /bin/bash -d ${AIRFLOW_HOME} airflow \
    && mkdir -p ${AIRFLOW_HOME}/.ssh \
    && mkdir -p ${AIRFLOW_HOME}/dags \
    && mkdir -p ${AIRFLOW_HOME}/dags/user_dags \
    && mkdir -p ${AIRFLOW_HOME}/dags/system_dags \
    && mkdir -p ${AIRFLOW_HOME}/config \
    && touch ${AIRFLOW_HOME}/dags/__init__.py \
    && touch ${AIRFLOW_HOME}/dags/user_dags/__init__.py \
    && touch ${AIRFLOW_HOME}/dags/system_dags/__init__.py \
    && touch ${AIRFLOW_HOME}/config/__init__.py \
    && cp -r /airflow//docker/deploy_dags.py ${AIRFLOW_HOME}/dags/system_dags \
    && cp -r /airflow/docker/log_config.py ${AIRFLOW_HOME}/config/log_config.py \
    && pip install -U pip setuptools wheel \
    && pip install Cython \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install /airflow[postgres,s3,datadog,celery,slack,password,crypto,redis] \
    && pip install celery[redis]==4.1.1 \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base \
        /airflow

COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

# This is expected to be checked out from git and cloned locally before buiilding
COPY root-airflow-plugins/root_airflow_plugins ${AIRFLOW_HOME}/plugins

RUN chown -R airflow:airflow ${AIRFLOW_HOME}
RUN ["chmod", "+x", "/entrypoint.sh"]

EXPOSE 8080 5555 8793

#USER airflow This is removed to be able to run entrypoint.sh as root and then step down using gosu
WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"]

