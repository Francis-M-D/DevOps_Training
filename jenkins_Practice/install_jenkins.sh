sudo apt update && sudo apt install -y openjdk-21-jdk

wget -qO /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key && echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >/dev/null

sudo apt update && sudo apt install -y jenkins

sudo systemctl start jenkins

sudo systemctl enable jenkins

sudo systemctl status jenkins

sudo usermod -aG shadow jenkins
