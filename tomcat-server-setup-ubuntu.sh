#!/bin/bash

# Exit the script on any error
set -e

# Update package list and install required packages
sudo apt update
sudo apt -y install openjdk-11-jdk git maven wget

# Download Tomcat
TOMURL="https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz"
cd /tmp/
wget $TOMURL -O tomcatbin.tar.gz
EXTOUT=$(tar xzvf tomcatbin.tar.gz)
TOMDIR=$(echo $EXTOUT | head -1 | cut -d '/' -f1)

# Create tomcat user and group
if ! id -u tomcat &>/dev/null; then
    sudo useradd --shell /sbin/nologin tomcat
fi

# Copy Tomcat files to /usr/local/tomcat
sudo rsync -avzh /tmp/$TOMDIR/ /usr/local/tomcat/

# Change ownership of the Tomcat directory
sudo chown -R tomcat:tomcat /usr/local/tomcat

# Remove existing Tomcat service file if it exists
sudo rm -rf /etc/systemd/system/tomcat.service

# Create the Tomcat service file
cat <<EOT | sudo tee /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
Group=tomcat
WorkingDirectory=/usr/local/tomcat

Environment=JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
Environment=CATALINA_PID=/var/run/tomcat.pid
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINA_BASE=/usr/local/tomcat

ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd and start Tomcat
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

# Clone the vprofile project repository
cd /opt
git clone -b main https://github.com/hkhcoder/vprofile-project.git
cd vprofile-project

# Build the project with Maven
mvn install || { echo "Maven build failed"; exit 1; }

# Deploy the WAR file
sudo systemctl stop tomcat
sleep 20
sudo rm -rf /usr/local/tomcat/webapps/ROOT*
sudo cp target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
sudo systemctl start tomcat

# Disable firewalld (Ubuntu uses ufw instead of firewalld)
sudo ufw disable || echo "Firewall not running"

# Restart Tomcat
sudo systemctl restart tomcat

