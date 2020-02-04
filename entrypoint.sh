#!/bin/bash

# User variables
#GCP_SVC_ACCOUNT_JSON=
GCP_PROJECT="gcp-project"
GCR_IMAGES_FILTER="prefix-"
# Exclude tags like master, develop, 1.0, v1.0
GCR_TAGS_EXCLUDE="latest master develop ^[0-9] ^v[0-9]"

# Technical variables
GCP_SVC_ACCOUNT_FILE=svc.json
GCR_REGISTRY="eu.gcr.io/${GCP_PROJECT}"

# Uuncompress svc account in container
#echo "${GCP_SVC_ACCOUNT_JSON}" | tr ' ' '\n'  | base64 -d > ${GCP_SVC_ACCOUNT_FILE}

# Login to gcloud
gcloud auth activate-service-account --project=${GCP_PROJECT} --key-file=${GCP_SVC_ACCOUNT_FILE}

# List docker images on GCR
GCR_IMAGES=$(gcloud container images list --repository=${GCR_REGISTRY} | grep "${GCR_IMAGES_FILTER}" | cut -d '/' -f3 | sed 's/^M//g'| tr '\n' ' ')
echo "Docker image list: ${GCR_IMAGES}"

# Build tags filter string
tags_exclude=""
for tag in ${GCR_TAGS_EXCLUDE} ; do
    tags_exclude="${tags_exclude} tags~${tag}"
done
tags_exclude=$(echo ${tags_exclude} | sed 's/ / OR /g')


# Browse on filtered docker images
for gcr_image in ${GCR_IMAGES} ; do
    echo "----------------------------"
    echo "Cleanup image ${gcr_image}"

    # Retrieve tags from docker image after filtering exclude items
    GCR_IMAGE_TAGS=$(gcloud container images list-tags ${GCR_REGISTRY}/${gcr_image} --format="get(digest)" --filter="NOT (${tags_exclude})" | sed 's/^M//g' | tr '\n' ' ')

    # Untag images
    GCR_IMAGE_TAGS_2=$(gcloud container images list-tags ${GCR_REGISTRY}/${gcr_image} --format="get(tags)" --filter="NOT (${tags_exclude})" | sed 's/^M//g' | tr '\n' ' ')
    for tag in $GCR_IMAGE_TAGS_2 ; do
        gcloud container images untag ${GCR_REGISTRY}/${gcr_image}:${tag} --quiet --no-user-output-enabled && echo "Tag removed: ${tag}" || echo "!! Error on deleting tag ${tag}"
    done

    # Browse on filtered docker image tags
    for gcr_image_tag in ${GCR_IMAGE_TAGS} ; do
        gcloud container images delete --quiet --no-user-output-enabled ${GCR_REGISTRY}/${gcr_image}@${gcr_image_tag} 2>/dev/null && echo "Image deleted: ${gcr_image_tag}" || echo "!! Error on deleting image ${gcr_image_tag}"
    done
done
