# This is the Containerfile for your custom image.

# Instead of adding RUN statements here, you should consider creating a script
# in `config/scripts/`. Read more in `modules/script/README.md`

# This Containerfile takes in the recipe, version, and base image as arguments,
# all of which are provided by build.yml when doing builds
# in the cloud. The ARGs have default values, but changing those
# does nothing if the image is built in the cloud.

# !! Warning: changing these might not do anything for you. Read comment above.
ARG BASE_IMAGE_URL=ghcr.io/ublue-os/silverblue-main

FROM ${BASE_IMAGE_URL}:${IMAGE_MAJOR_VERSION}
ARG AKMODS_FLAVOR="${AKMODS_FLAVOR:-main}"
ARG IMAGE_MAJOR_VERSION=39

# The default recipe is set to the recipe's default filename
# so that `podman build` should just work for most people.
ARG RECIPE=recipe.yml
# The default image registry to write to policy.json and cosign.yaml
ARG IMAGE_REGISTRY=ghcr.io/ublue-os

COPY cosign.pub /usr/share/ublue-os/cosign.pub

# Add ublue kmods, add needed negativo17 repo and then immediately disable due to incompatibility with RPMFusion
COPY --from=ghcr.io/ublue-os/akmods:${AKMODS_FLAVOR}-${IMAGE_MAJOR_VERSION} /rpms/ /tmp/akmods-rpms
RUN find /tmp/akmods-rpms && \
    wget https://negativo17.org/repos/fedora-multimedia.repo -O /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    rpm-ostree install \
        /tmp/akmods-rpms/kmods/kmod-evdi-*.rpm \
        /tmp/akmods-rpms/kmods/kmod-v4l2loopback*.rpm \
        /tmp/akmods-rpms/kmods/kmod-VirtualBox*.rpm && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo

# Copy build scripts & configuration
COPY build.sh /tmp/build.sh
COPY config /tmp/config/

# Copy modules
# The default modules are inside ublue-os/bling
COPY --from=ghcr.io/ublue-os/bling:latest /modules /tmp/modules/
# Custom modules overwrite defaults
COPY modules /tmp/modules/

# `yq` is used for parsing the yaml configuration
# It is copied from the official container image since it's not available as an RPM.
COPY --from=docker.io/mikefarah/yq /usr/bin/yq /usr/bin/yq

# Change this if you want different version/tag of akmods.
COPY --from=ghcr.io/ublue-os/akmods:main-39 /rpms /tmp/rpms

# Run the build script, then clean up temp files and finalize container build.
RUN chmod +x /tmp/build.sh && /tmp/build.sh && \
    rm -rf /tmp/* /var/* && ostree container commit
