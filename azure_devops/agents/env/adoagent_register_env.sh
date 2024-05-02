#!/bin/bash

# Initialize variables
devops_env=""
#admin_username=""
#admin_password=""
ado_org_url=""
ado_project=""
ado_pat=""
adoagent_latest_version=""
env_tags=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -devops_env) devops_env="$2"; shift ;;
        #-admin_username) admin_username="$2"; shift ;;
        #-admin_password) admin_password="$2"; shift ;;
        -ado_org_url) ado_org_url="$2"; shift ;;
        -ado_project) ado_project="$2"; shift ;;
        -ado_pat) ado_pat="$2"; shift ;;
        -adoagent_latest_version) adoagent_latest_version="$2"; shift ;;
        -env_tags) env_tags="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

check_admin() {
    if [ "$EUID" -eq 0 ]
    then echo "Please do not run as root or with sudo"
    exit
    fi
}

check_libicu() {
    echo "Checking if libicu is installed..."
    if ! rpm -q libicu; then
        echo "libicu is not installed. Installing..."
        sudo dnf install -y libicu
    else
        echo "libicu is already installed."
    fi
}

configure_agent() {
    echo "Configuring agent..."
    echo "Making azagent directory"
    mkdir -p azagent
    echo "Changing directory to azagent"
    cd azagent
    echo "Downloading agent..."
    curl -fkSL -o vstsagent.tar.gz https://vstsagentpackage.azureedge.net/agent/${adoagent_latest_version}/vsts-agent-linux-x64-${adoagent_latest_version}.tar.gz
    echo "Extracting agent..."
    echo "Present working directory: $(pwd)"
    tar -zxvf vstsagent.tar.gz
    echo "Printing contents of azagent directory"
    echo "Present working directory: $(pwd)"
    ls -la
    if [ -x "$(command -v systemctl)" ]; then
        echo "Running config.sh with --runasservice"
        sleep 10
        ./config.sh --unattended --environment --environmentname "${devops_env}" --acceptteeeula --agent $HOSTNAME --url "${ado_org_url}" --work _work --projectname "${ado_project}" --auth PAT --token "${ado_pat}" --addvirtualmachineresourcetags --virtualmachineresourcetags "${env_tags}" --runasservice
        attempt=0
        max_attempts=5
        while [ ! -f "./svc.sh" ] && [ $attempt -le $max_attempts ]; do
            echo "Waiting for svc.sh to be available... Attempt: $((attempt+1))"
            sleep 5
            attempt=$((attempt+1))
        done
        if [ -f "./svc.sh" ]; then
            echo "Present working directory: $(pwd)"
            if systemctl is-active --quiet svc; then
                sudo bash svc.sh restart
            else
                sudo bash svc.sh install
                sudo bash svc.sh start
            fi        
        else
            echo "svc.sh not found after $max_attempts attempts"
            exit 1
        fi
    else
        echo "Running config.sh without --runasservice"
        ./config.sh --unattended --environment --environmentname "${devops_env}" --acceptteeeula --agent $HOSTNAME --url "${ado_org_url}" --work _work --projectname "${ado_project}" --auth PAT --token "${ado_pat}" --addvirtualmachineresourcetags --virtualmachineresourcetags "${env_tags}"
        ./run.sh
    fi
    echo "Agent configured"
}

# Call functions
check_admin
check_libicu
configure_agent
