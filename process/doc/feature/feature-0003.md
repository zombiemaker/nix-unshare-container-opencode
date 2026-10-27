---
spec_id: "0003"
feature_category: process feature
feature_name: "Can Run OCI Container Images Using Podman"
---
# Description
Within container enviroment, can run OCI container images using Podman

# Capabilities
- List container images in on-machine image cache
`podman images`

- Pull container images from https://hub.docker.com/
`podman pull docker.io/library/nginx:latest`

- Run container images from https://hub.docker.com/
`podman run -it --rm docker.io/library/nginx:latest`