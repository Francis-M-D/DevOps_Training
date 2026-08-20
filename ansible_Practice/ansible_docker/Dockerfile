FROM ghostatdocker/ansible_ubuntu:V1.1

WORKDIR /etc/ansible

COPY ansible.cfg .

RUN chown ansibleusr:ansibleusr /etc/ansible/ansible.cfg

CMD ["/bin/bash", "-c", "service ssh start && exec /bin/bash"]
