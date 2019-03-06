set -ex
WORKSPACE=${WORKSPACE:-/tmp}
ANSIBLE_HOSTS=${ANSIBLE_HOSTS:-$WORKSPACE/hosts}
LOGSERVER="logs.rdoproject.org ansible_user=uploader"
SOURCE="/tmp/kolla/logs"
DESTINATION="/var/www/html/ci.centos.org/${JOB_NAME}/${BUILD_NUMBER}"

# Add logserver to the ansible_hosts file
cat << EOF >> ${ANSIBLE_HOSTS}
[logserver]
${LOGSERVER}
EOF

pushd $WORKSPACE
mkdir -p $WORKSPACE/logs

# Ensure Ansible is installed and available
[[ ! -d provision_venv ]] && virtualenv provision_venv
provision_venv/bin/pip install ansible

cat << EOF > collect-logs.yaml
# Create a playbook to pull the logs down from our cico node
- name: Collect logs from cico node
  hosts: openstack_nodes
  gather_facts: no
  tasks:
      synchronize:
          mode: pull
          src: "${SOURCE}"
          dest: "${WORKSPACE}/logs/"

- name: Send logs to the log server
  hosts: logserver
  gather_facts: no
  tasks:
    - name: Create log destination directory
      file:
        path: "${DESTINATION}"
        state: directory
        recurse: yes

    - name: Upload logs to log server
      synchronize:
        src: "${WORKSPACE}/logs"
        dest: "${DESTINATION}/"
EOF

provision_venv/bin/pip ansible-playbook -i "${ANSIBLE_HOSTS}" collect-logs.yaml
popd
