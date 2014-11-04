#! /bin/bash

function sftpTo() {
    local source="$1"
    local dest="$2"

    sshpass -p 'CHWUHq5E' sftp -oBatchMode=no -b - PMX@panamax.ingest.cdn.level3.net << !
    cd $dest
    put $1
    quit
!
}

if [[ "$#" != "2" ]]; then
    echo "usage: ./update.sh branch version"
    exit 1;
fi

git_branch="$1"
next_version="panamax-agent-$2.tar.gz"
latest_version="panamax-agent-latest.tar.gz"

mkdir -p installs
rm -Rf panamax-remote-agent-installer
mkdir -p panamax-remote-agent-installer

git clone -b "$git_branch" https://github.com/CenturyLinkLabs/panamax-remote-agent-installer.git panamax-remote-agent-installer
cd panamax-remote-agent-installer

git checkout ${git_branch}
echo $2 > .version

tar -cvzf $next_version . --exclude=.git* --exclude=update.sh --exclude=panamax-*.tar.gz --exclude=pmx-agent-install
cp ${next_version} ${latest_version}

#git commit . -m "Updating to version $2"
#git push
#git tag -a v$2 -m "Version $2"
#git push --tags

sftpTo pmx-agent-install agent
sftpTo ${next_version} agent
sftpTo ${latest_version} agent

cd ..
