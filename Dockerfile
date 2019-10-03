FROM continuumio/miniconda3:latest

ADD https://github.com/milaboratory/mixcr/releases/download/v3.0.9/mixcr-3.0.9.zip /software/
ADD https://github.com/ShalekLab/mixcr_workflow/blob/master/imgt.201918-4.sv5.json.gz?raw=true /tmp/

RUN apt-get update && apt-get install --no-install-recommends -y curl dpkg-dev gnupg lsb-release procps \
	&& export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
	&& echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
	&& curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
	&& apt-get update && apt-get install -y google-cloud-sdk

RUN apt-get -qq update && apt-get -qq -y install --no-install-recommends default-jre unzip zip \
	&& unzip /software/mixcr-3.0.9.zip \ 
	&& rm /software/mixcr-3.0.9.zip \
	&& gunzip /tmp/imgt.201918-4.sv5.json.gz \
	&& rm /tmp/imgt.201918-4.sv5.json.gz

ENV PATH="/software/mixcr-3.0.9/:${PATH}"