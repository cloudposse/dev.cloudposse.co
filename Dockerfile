FROM cloudposse/terraform-root-modules:0.5.4 as terraform-root-modules

FROM cloudposse/helmfiles:0.4.0 as helmfiles

FROM cloudposse/geodesic:0.21.0

ENV DOCKER_IMAGE="cloudposse/dev.cloudposse.co"
ENV DOCKER_TAG="latest"

# Geodesic banner
ENV BANNER="dev.cloudposse.co"

# AWS Region
ENV AWS_REGION="us-west-2"

# Terraform vars
ENV TF_VAR_region="${AWS_REGION}"
ENV TF_VAR_account_id="838456590850"
ENV TF_VAR_namespace="cpco"
ENV TF_VAR_stage="dev"
ENV TF_VAR_domain_name="dev.cloudposse.co"
ENV TF_VAR_zone_name="dev.cloudposse.co."

# chamber KMS config
ENV CHAMBER_KMS_KEY_ALIAS="alias/${TF_VAR_namespace}-${TF_VAR_stage}-chamber"

# Terraform State Bucket
ENV TF_BUCKET_REGION="${AWS_REGION}"
ENV TF_BUCKET="${TF_VAR_namespace}-${TF_VAR_stage}-terraform-state"
ENV TF_DYNAMODB_TABLE="${TF_VAR_namespace}-${TF_VAR_stage}-terraform-state-lock"

# Default AWS Profile name
ENV AWS_DEFAULT_PROFILE="${TF_VAR_namespace}-${TF_VAR_stage}-admin"

# Copy root modules
COPY --from=terraform-root-modules /aws/tfstate-backend/ /conf/tfstate-backend/
COPY --from=terraform-root-modules /aws/account-dns/ /conf/account-dns/
COPY --from=terraform-root-modules /aws/acm/ /conf/acm/
COPY --from=terraform-root-modules /aws/backing-services/ /conf/backing-services/
COPY --from=terraform-root-modules /aws/chamber/ /conf/chamber/
COPY --from=terraform-root-modules /aws/cloudtrail/ /conf/cloudtrail/
COPY --from=terraform-root-modules /aws/kops/ /conf/kops/
COPY --from=terraform-root-modules /aws/kops-aws-platform/ /conf/kops-aws-platform/

# Copy helmfiles
COPY --from=helmfiles /helmfile.d/ /conf/helmfile.d/
COPY --from=helmfiles /scripts/ /conf/scripts/

# Place configuration in 'conf/' directory
COPY conf/ /conf/

# Filesystem entry for tfstate
RUN s3 fstab '${TF_BUCKET}' '/' '/secrets/tf'

# kops config
ENV KUBERNETES_VERSION="1.9.6"
ENV KOPS_CLUSTER_NAME="us-west-2.dev.cloudposse.co"
ENV KOPS_DNS_ZONE=${KOPS_CLUSTER_NAME}
ENV KOPS_STATE_STORE="s3://${TF_VAR_namespace}-${TF_VAR_stage}-kops-state"
ENV KOPS_STATE_STORE_REGION="us-west-2"
ENV KOPS_AVAILABILITY_ZONES="us-west-2a,us-west-2b,us-west-2c"
ENV KOPS_BASTION_PUBLIC_NAME="bastion"
ENV BASTION_MACHINE_TYPE="t2.medium"
ENV MASTER_MACHINE_TYPE="t2.medium"
ENV NODE_MACHINE_TYPE="t2.medium"
ENV NODE_MAX_SIZE="2"
ENV NODE_MIN_SIZE="2"

# Generate kops manifest
RUN build-kops-manifest

WORKDIR /conf/
