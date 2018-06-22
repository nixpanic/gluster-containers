FROM centos:7

MAINTAINER Niels de Vos <ndevos@redhat.com>

ENV container docker

LABEL architecture="x86_64" \
      name="gluster/glusterfs-server" \
      version="4.0" \
      vendor="CentOS Community" \
      summary="This image has a running glusterfs service ( CentOS 7 + Gluster 4.0)" \
      io.k8s.display-name="Gluster 4.0 based on CentOS 7" \
      io.k8s.description="Gluster Image is based on CentOS Image which is a scalable network filesystem. Using common off-the-shelf hardware, you can create large, distributed storage solutions for media streaming, data analysis, and other data- and bandwidth-intensive tasks." \
      description="Gluster Image is based on CentOS Image which is a scalable network filesystem. Using common off-the-shelf hardware, you can create large, distributed storage solutions for media streaming, data analysis, and other data- and bandwidth-intensive tasks." \
      io.openshift.tags="gluster,glusterfs,glusterfs-centos"

RUN yum --setopt=tsflags=nodocs -y update && \
    yum --setopt=tsflags=nodocs -y install centos-release-gluster && \
    yum --setopt=tsflags=nodocs -y install glusterfs-server  && \
    yum clean all && rm -rf /var/cache/yum && \
    sed 's/ENV{DM_UDEV_DISABLE_OTHER_RULES_FLAG}=="1", ENV{SYSTEMD_READY}="0"/ENV{DM_UDEV_DISABLE_OTHER_RULES_FLAG}=="1", GOTO="systemd_end"/g' /usr/lib/udev/rules.d/99-systemd.rules > /etc/udev/rules.d/99-systemd.rules && \
    sed -i -e "s#udev_sync = 1#udev_sync = 0#" -e "s#udev_rules = 1#udev_rules = 0#" -e "s#use_lvmetad = 1#use_lvmetad = 0#" /etc/lvm/lvm.conf && \
    mkdir -p /etc/glusterfs_bkp /var/lib/glusterd_bkp /var/log/glusterfs_bkp && \
    cp -r /etc/glusterfs/* /etc/glusterfs_bkp && \
    cp -r /var/lib/glusterd/* /var/lib/glusterd_bkp && \
    cp -r /var/log/glusterfs/* /var/log/glusterfs_bkp

VOLUME [ "/sys/fs/cgroup" ]
VOLUME [ "/lib/modules" ]

ADD gluster-setup.service /etc/systemd/system/gluster-setup.service
ADD container-setup.sh /usr/libexec/glusterfs/container-setup.sh

RUN chmod 644 /etc/systemd/system/gluster-setup.service && \
    chmod 755 /usr/libexec/glusterfs/container-setup.sh && \
    systemctl mask getty.target && \
    systemctl enable gluster-setup.service && \
    systemctl enable glusterd.service

EXPOSE 24007 49152 49153 49154 49156 49157 49158 49159 49160 49161 49162

CMD ["/usr/sbin/init"]
