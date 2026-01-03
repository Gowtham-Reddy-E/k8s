FROM rockylinux:8

ENV DISPLAY=:1

# Force stable Rocky repos (disable mirrorlist)
RUN sed -i \
    -e 's|^mirrorlist=|#mirrorlist=|g' \
    -e 's|^#baseurl=http://dl.rockylinux.org|baseurl=https://dl.rockylinux.org|g' \
    /etc/yum.repos.d/Rocky-*.repo

# Install desktop + VNC
RUN dnf -y install epel-release && \
    dnf -y groupinstall "Xfce" && \
    dnf -y install tigervnc-server && \
    dnf clean all

# VNC config
RUN mkdir -p /root/.vnc && \
    echo "centos" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# XFCE startup (avoid gray screen)
RUN cat << 'EOF' > /root/.vnc/xstartup
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4 &
EOF

RUN chmod +x /root/.vnc/xstartup

# Startup script
RUN cat << 'EOF' > /start.sh
#!/bin/bash
vncserver :1 -geometry 1280x800 -depth 24
tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 5901

CMD ["/start.sh"]
