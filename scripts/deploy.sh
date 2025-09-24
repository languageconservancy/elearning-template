#!/bin/bash

#------------------------------------------------------------------------------#
# Description
#------------------------------------------------------------------------------#
# - Used to install the E-Learning Platform to a server (both web frontend and backend)
# - Steps that the script does:
#   1. Parse command-line arguments (build-type, skip-frontend, skip-backend)
#   2. Create variables of paths and print them out for user
#   3. Create diff (files changed) from current commit to last tag.
#      Save them to:
#        owoksape-docker-build/tmp/owoksape-web-app.diff
#        owoksape-docker-build/tmp/owoksape-backend.diff
#   4. Create commit info for each repo and store it in a file
#      Save them to:
#        public_html/commit-info-frontend.txt and
#        public_html/backend/commit-info-backend.txt
#   5. Build frontend and copy dist files to public_html. Copies all files
#      in dist except assets, and copies assets/images.
#   6. Copy backend src and composer files to public_html/backend and
#      run composer update --no-interaction --no-dev to update non-dev dependencies

# Exit on error and pipefail
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Source the deploy-vars.sh file
source ${SCRIPT_DIR}/deploy-vars.sh

#------------------------------------------------------------------------------#
# Text colors
#------------------------------------------------------------------------------#
RED='\033[0;31m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
COLOR_RESET='\033[0m' # No Color

#------------------------------------------------------------------------------#
# Global variables
#------------------------------------------------------------------------------#
PARAMS=""
# Command-line arguments
buildType=""
commandType=""
runFrontend=false
runBackend=false
dryRun=false
skipConfirmation=false
backupPublicHtml=false
setPermissions=false
overrideTagBranchCheck=false
# Global variables
sshIdentityFile="${PRODUCTION_SSH_IDENTITY_FILE}"
versionFileContainsInfo=false
serverUser=""
documentRoot=""
extraBackendFilesToInstall=""

# Global constants
readonly VALID_BUILD_TYPES=(
    "production"
    "staging"
)
readonly VALID_COMMANDS=("install" "createrelease")
readonly PLATFORM_REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd .. && pwd )"
readonly CORE_DIR="${PLATFORM_REPO_DIR}/core"
readonly FRONTEND_DIR="${CORE_DIR}/frontend"
readonly BACKEND_DIR="${CORE_DIR}/backend"
readonly NG_BINARY="${FRONTEND_DIR}/node_modules/@angular/cli/bin/ng.js"
readonly COMPOSER_BINARY="composer"
readonly FRONTEND_DIST_FILES="*.js *.css dist-resources assets favicon.ico 3rdpartylicenses.txt index.html"
readonly BACKEND_DIST_FILES=".htaccess .bowerrc src templates bin config/Migrations config/app.php config/app_local.php config/schema config/bootstrap.php config/bootstrap_cli.php config/paths.php config/requirements.php config/routes.php config/allowed_routes.php info plugins composer.json index.php info.php web.config webroot/.htaccess webroot/favicon.ico webroot/index.php webroot/css webroot/font webroot/js webroot/templates" # webroot/img/*.*"
readonly BACKEND_EXTRA_DIST_FILES_TO_REMOVE="vendor composer.lock"
readonly -a REQUIRED_CMDS=("zip" "awk" "rm" "mkdir" "ssh" "scp")
readonly TEMP_DIR_NAME="tmpdir"
readonly OWNER="languageconservancy"

confirm_production_install() {
    if [[ "install" == "${commandType}" && "${buildType}" == *"production"* ]]; then
        read -n 1 -p "You are about to deploy to the production site '${buildType}'. Are you sure? (y/n): " response
        while [[ "${response}" != "y" && "${response}" != "n" ]];
        do
            echo -e "\nPlease respond with 'y' or 'n': "
            read -n 1 response
        done
        if [[ ${response} != "y" ]]; then
            print_notice "\nInstallation cancelled by user. Exiting..."
            exit 0
        fi
    else
        echo "'$commandType' and '$buildType'"
    fi
}

# Defines build name to server user
set_server_user() {
    backendConfig="${buildType}"
    case "${buildType}" in
        "production")
            serverUser="${PRODUCTION_SERVER_USER}"
            documentRoot="${PRODUCTION_DOCUMENT_ROOT}"
            domainRoot="${PRODUCTION_DOMAIN_ROOT}"
            sshIdentityFile="${PRODUCTION_SSH_IDENTITY_FILE}"
            sshHost="${PRODUCTION_SSH_HOST}"
            sshUser="${PRODUCTION_SSH_USER}"
            # ensure all variables are set
            check_variable ${serverUser} "Server user didn't get defined. Reason: unknown."
            check_variable ${documentRoot} "Document root didn't get defined. Reason: unknown."
            check_variable ${domainRoot} "Domain root didn't get defined. Reason: unknown."
            check_variable ${sshIdentityFile} "SSH identity file didn't get defined. Reason: unknown."
            check_variable ${sshHost} "SSH host didn't get defined. Reason: unknown."
            check_variable ${sshUser} "SSH user didn't get defined. Reason: unknown."
            ;;
        "staging")
            serverUser="${STAGING_SERVER_USER}"
            documentRoot="${STAGING_DOCUMENT_ROOT}"
            domainRoot="${STAGING_DOMAIN_ROOT}"
            sshIdentityFile="${STAGING_SSH_IDENTITY_FILE}"
            sshHost="${STAGING_SSH_HOST}"
            sshUser="${STAGING_SSH_USER}"
            # ensure all variables are set
            check_variable ${serverUser} "Server user didn't get defined. Reason: unknown."
            check_variable ${documentRoot} "Document root didn't get defined. Reason: unknown."
            check_variable ${domainRoot} "Domain root didn't get defined. Reason: unknown."
            check_variable ${sshIdentityFile} "SSH identity file didn't get defined. Reason: unknown."
            check_variable ${sshHost} "SSH host didn't get defined. Reason: unknown."
            check_variable ${sshUser} "SSH user didn't get defined. Reason: unknown."
            ;;
        *)
            print_error "\n⚠️ Error: Build type of '${buildType}' is not valid"
            show_usage
            exit 1
        ;;
    esac
}

#------------------------------------------------------------------------------#
# Simple util functions
#------------------------------------------------------------------------------#
print_error() {
    echo -e "${RED}$1${COLOR_RESET}"
}

print_heading() {
    echo -e "${CYAN}$1${COLOR_RESET}"
}

print_notice() {
    echo -e "${CYAN}$1${COLOR_RESET}"
}

print_dryrun_msg() {
    echo -e "${CYAN}Dry-run: ${COLOR_RESET}$1"
}

verify_file_or_dir_exists() {
    if [ ! -f "$1" ] && [ ! -d "$1" ]; then
        print_error "⚠️ Error: $1 doesn't exist. Exiting..."
        exit 1
    fi
}

verify_alias_is_valid() {
    cmd=`type $1 | awk 'END {print $NF}'` # Get alias string
    cmd="${1:1}" # Remove initial apostrophe
    cmd="${cmd%?}" # Remove end apostrophe
    which $cmd
    ret="$?"
    if [ "$ret" == "" ]; then
        print_error "⚠️ Error: aliased command \'$cmd\' doesn't exist. Exiting..."
        exit 1
    fi
}

verify_files_and_dirs_exist() {
    set -v # turn on output capture
    verify_file_or_dir_exists ${CORE_DIR}
    verify_file_or_dir_exists ${FRONTEND_DIR}
    verify_file_or_dir_exists ${BACKEND_DIR}
    set +v # turn off output capture
}

#------------------------------------------------------------------------------#
# main functions
#------------------------------------------------------------------------------#

delete_frontend_old_dist_directory() {
    if [ -d "${FRONTEND_DIR}/dist" ]; then
        print_heading "\nDeleting local frontend's old dist directory"
        if ${dryRun} ; then
            print_dryrun_msg "rm -r ${FRONTEND_DIR}/dist"
        else
            set -x # turn on mode that prints all commands to terminal
            rm -r ${FRONTEND_DIR}/dist
            set +x # turn off mode that prints all commands to terminal
        fi
    fi
}

delete_frontend_old_server_files() {
    print_heading "\nRemoving server frontend's old files from public_html directory"

    if ${dryRun} ; then
        print_dryrun_msg "ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} \"sudo sh -c 'cd ${documentRoot} && rm -rIf ${FRONTEND_DIST_FILES}'\""
    else
        set -x # turn on mode that prints all commands to terminal
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'cd ${documentRoot} && rm -rIf ${FRONTEND_DIST_FILES}'"
        set +x # turn off mode that prints all commands to terminal
    fi
}

copy_frontend_to_server() {
    print_heading "\nCopying frontend files to server"

    if ${dryRun} ; then
        echo "Copying frontend files to server"
    else
        set -x # turn on mode that prints all commands to terminal
        rm -rf ${CORE_DIR}/${TEMP_DIR_NAME} && mkdir -p ${CORE_DIR}/${TEMP_DIR_NAME}
        # zip frontend files to copy to server
        cd ${FRONTEND_DIR}/dist && zip -rD ${CORE_DIR}/${TEMP_DIR_NAME}/dist.zip ${FRONTEND_DIST_FILES}
        # create helper folder on server for unzipping
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "mkdir -p ${buildType}-install-files-to-copy"
        # copy zip file over to server
        scp -i ${sshIdentityFile} -pr ${CORE_DIR}/${TEMP_DIR_NAME}/dist.zip ${sshUser}@${sshHost}:${buildType}-install-files-to-copy/
        # unzip file
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "cd /home/${sshUser}/${buildType}-install-files-to-copy/ && unzip dist.zip && rm dist.zip"
        # copy unzipped files to document root on server
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'cd /home/${sshUser}/${buildType}-install-files-to-copy/ && rsync -azR ./ ${documentRoot}/'"
        # delete temp dir on server
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo rm -r /home/${sshUser}/${buildType}-install-files-to-copy"
        # delete temp dir locally
        rm -rf ${CORE_DIR}/${TEMP_DIR_NAME}
        set +x # turn off mode that prints all commands to terminal
    fi
}

change_ownership_and_permissions() {
    if [ "$#" != "1" ]; then
        print_error "⚠️ change_ownership_and_permissions() didn't receive one argument"
        exit 1
    fi
    dir=$1
    print_heading "Changing $dir ownership to ${serverUser}:${serverUser} and permissions to 755 for directories and 0644 for files"
    if ${dryRun} ; then
        echo "Changing ownership and permissions on $dir"
    else
        set -x # turn on mode that prints all commands to terminal
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo chown ${serverUser}:${serverUser} -R $dir"
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo find $dir -type d -exec chmod 755 {} +"
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo find $dir -type f -exec chmod 644 {} +"
        set +x # turn off mode that prints all commands to terminal
    fi
}

build_backend() {
    print_heading "Updating local backend composer packages"

    if ${dryRun} ; then
        echo "Updating local backend composer packages"
    else
        set -x # turn on mode that prints all commands to terminal
        cd ${BACKEND_DIR} && composer update --no-interaction --no-dev
        set +x # turn off mode that prints all commands to terminal
    fi
}

delete_backend_old_server_files() {
    print_heading "\nRemoving server backend's old files from public_html directory"

    if ${dryRun} ; then
        echo "Removing server backend's old files from public_html directory"
    else
        set -x # turn on mode that prints all commands to terminal
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'mkdir -p ${documentRoot}/backend && cd ${documentRoot}/backend && rm -rIf ${BACKEND_DIST_FILES} ${BACKEND_EXTRA_DIST_FILES_TO_REMOVE}'"
        set +x # turn off mode that prints all commands to terminal
    fi
}

copy_backend_to_server() {
    print_heading "\nCopying backend files to server"

    if ${dryRun} ; then
        echo "Copying backend files to server"
    else
        set -x # turn on mode that prints all commands to terminal
        rm -rf ${CORE_DIR}/${TEMP_DIR_NAME}
        mkdir -p ${CORE_DIR}/${TEMP_DIR_NAME}
        # create local and server temp directories
        cd ${BACKEND_DIR} && rsync -azR --exclude='.env' ${BACKEND_DIST_FILES} ${extraBackendFilesToInstall} ${CORE_DIR}/${TEMP_DIR_NAME}/
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "mkdir -p ${buildType}-install-files-to-copy"
        # zip backend files
        cd ${CORE_DIR} && zip -rD ./${TEMP_DIR_NAME}/backend.zip ./${TEMP_DIR_NAME}
        # copy zip file to server
        scp -i ${sshIdentityFile} -pr ${CORE_DIR}/${TEMP_DIR_NAME}/backend.zip ${sshUser}@${sshHost}:${buildType}-install-files-to-copy/
        # unzip zip file
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'cd /home/${sshUser}/${buildType}-install-files-to-copy/ && unzip backend.zip && rm backend.zip'"
        # copy files to backend directory with relative paths
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'mkdir -p ${documentRoot}/backend/ && cd /home/${sshUser}/${buildType}-install-files-to-copy/${TEMP_DIR_NAME}/ && rsync -azR ./ ${documentRoot}/backend/ && cp -r ${documentRoot}/backend/info ${documentRoot}/ && sudo rm -r /home/${sshUser}/${buildType}-install-files-to-copy'"
        # delete temp directory locally
        rm -r ${CORE_DIR}/${TEMP_DIR_NAME}
        # delete model cache files on server in backend
        print_heading "\nDelete cached model files on server"
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'rm -vf ${documentRoot}/backend/tmp/cache/models/*'"
        set +x # turn off mode that prints all commands to terminal
    fi
}

install_backend_composer_packages() {
    print_heading "\nInstalling server backend composer packages"

    if ${dryRun} ; then
        echo "Installing server backend composer packages"
    else
        echo "The following password prompt is for the ${serverUser} user on the server"
        set -x # turn on mode that prints all commands to terminal
        ssh -t -i ${sshIdentityFile} ${sshUser}@${sshHost} "su -c 'cd ${documentRoot}/backend && composer update --no-interaction --no-dev' ${serverUser}"
        set +x # turn off mode that prints all commands to terminal
    fi
}

add_frontend_version_file_to_server() {
    print_heading "\nCreate frontend version info file on server"

    if ${dryRun} ; then
        echo "Creating frontend version info file on server"
    else
        set -x # turn on mode that prints all commands to terminal
        platformTag=`cd ${PLATFORM_REPO_DIR} && git describe --tags --abbrev=0`
        platformCommitHash=`cd ${PLATFORM_REPO_DIR} && git rev-parse HEAD`
        platformCommitDate=`cd ${PLATFORM_REPO_DIR} && git show -s --format=%ci HEAD`
        ngVersion=`cd ${PLATFORM_REPO_DIR} && ${NG_BINARY} version`
        set +x # turn off mode that prints all commands to terminal
        # remove ASCII Angular image cause it invalidates bash command
        searchString="Angular CLI:"
        toPrint=${ngVersion#*$searchString}

    text="Platform
    Tag: ${platformTag}
    Commit hash: ${platformCommitHash}
    Commit date: ${platformCommitDate}
    Local repo angular:
${searchString}${toPrint}"

        set -x # turn on mode that prints all commands to terminal
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'echo \"${text}\" > ${documentRoot}/platform_version_info.txt'"
        set +x # turn off mode that prints all commands to terminal
    fi
}

add_backend_version_file_to_server() {
    print_heading "\nCreate backend version info file on server"

    if ${dryRun} ; then
        echo "Creating backend version info file on server"
    else
        set -x # turn on mode that prints all commands to terminal
        backendTag=`cd ${BACKEND_DIR} && git describe --tags --abbrev=0`
        backendCommitHash=`cd ${BACKEND_DIR} && git rev-parse HEAD`
        backendCommitDate=`cd ${BACKEND_DIR} && git show -s --format=%ci HEAD`
        composerVersion=`ssh -t -i ${sshIdentityFile} ${sshUser}@${sshHost} "composer --version"`
        set +x # turn off mode that prints all commands to terminal

    text="Backend
    Tag: ${backendTag}
    Commit hash: ${backendCommitHash}
    Commit date: ${backendCommitDate}
    Server system composer:
    ${composerVersion}"

        set -x # turn on mode that prints all commands to terminal
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'echo \"${text}\" > ${documentRoot}/backend_version_info.txt'"
        set +x # turn off mode that prints all commands to terminal
    fi
}

backup_public_html() {
    local suffix=`date +"%Y-%m-%d-%H-%M-%S"`
    local dir="${domainRoot}/public_html_backups/public_html-${suffix}"
    print_heading "\nBacking up ${documentRoot} to ${dir} on server"

    if ${dryRun} ; then
        echo "Backing up ${documentRoot} to ${dir} on server"
    else
        set -x # turn on mode that prints all commands to terminal
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'mkdir -p ${domainRoot}/public_html_backups'"
        ssh -i ${sshIdentityFile} ${sshUser}@${sshHost} "sudo sh -c 'zip -rDq ${dir}.zip ${documentRoot}'"
        change_ownership_and_permissions ${dir}.zip
        set +x # turn off mode that prints all commands to terminal
    fi
}

print_settings() {
    print_heading "Command-line arguments:"
    echo "  build-type:          ${buildType}"
    echo "  command-type:        ${commandType}"
    echo "  frontend:            ${runFrontend}"
    echo "  backend:             ${runBackend}"
    echo "  dryrun:              ${dryRun}"
    echo "  backupPublicHtml:    ${backupPublicHtml}"
    print_heading "Variables:"
    echo "  sshIdentityFile:     ${sshIdentityFile}"
    echo "  versionFileContainsInfo: ${versionFileContainsInfo}"
    echo "  serverUser:          ${serverUser}"
    echo "  documentRoot:        ${documentRoot}"
    echo "  backendConfig:       ${backendConfig}"
    print_heading "Constants:"
    echo "  CORE_DIR:            ${CORE_DIR}"
    echo "  FRONTEND_DIR:        ${FRONTEND_DIR}"
    echo "  BACKEND_DIR:         ${BACKEND_DIR}"
    echo "  NG_BINARY:           ${NG_BINARY}"
    echo "  COMPOSER_BINARY:     ${COMPOSER_BINARY}"
    echo "  SSH_USER:            ${sshUser}"
    echo "  SSH_HOST:            ${sshHost}"
    echo "  FRONTEND_DIST_FILES: ${FRONTEND_DIST_FILES}"
    echo "  BACKEND_DIST_FILES:  ${BACKEND_DIST_FILES}"
}

show_usage() {
echo "
Description:
    Installation script for installing the platform and copying it to the server.
    To install the platform:
        $ ./install_release.sh -t staging -c install
    To create a GitHub release for the platform:
        $ ./install_release.sh -t production -c createrelease

Usage:
    -b|--backend                    (Perform command from -c arg for backend)
    -c|--command-type <command>     (Command to perform.
        'install' installs the platform, whichever environment is specified.
        'createrelease' creates a GitHub release for the platform if on main branch and tagged.
    -h|--help                       (Show this help message)
    -i|--identity-file path         (Path to ssh identity file, defaults to $HOME/.ssh/TLC.pem)
    -k|--skip-confirmation          (Skip confirmation for production install)
    -o|--override-tag-branch-check  (Override tag and branch check)
    -s|--set-permissions            (Set permissions on public_html and public_html_backups)
    -t|--build-type <type           (Type of build. <type> can be one of the following: <production|staging>)
    --backup                        (Back up public_html to public_html-Y-M-D-H-M-S)
    --dryrun                        (Don't run any serious commands, just print them)

Examples:
    ./install_release.sh -t staging -c install -f
    ./install_release.sh -t production -c install -f -b --dryrun

Frontend files that get installed:
${FRONTEND_DIST_FILES}

Backend files that get installed:
${BACKEND_DIST_FILES}
"
}

check_variable() {
    if [ "$#" == "1" ]; then
        print_error "\nError: $1"
        show_usage
        exit 1
    elif [ "$#" == "0" ]; then
        print_error "\nError: no arguments passed to check_variable() function"
        show_usage
        exit 1
    fi
}

check_commands_exist() {
    cmds=("$@")
    print_notice "Checking for required commands..."
    for cmd in "${cmds[@]}"
    do
        which ${cmd}
        retval=$?
        if [ "${retval}" != "0" ]; then
            echo -e "'${cmd}'... ${RED}not found${COLOR_RESET} (result: ${retval}). Please see the readme and install ${cmd}"
            exit 1
        else
            echo -e "'${cmd}'... ${GREEN}found${COLOR_RESET}"
        fi
    done
}

ensure_on_branch_main() {
    if [ ${overrideTagBranchCheck} == "true" ]; then
        return
    fi
    repoDir=$1
    if [ ! -d "${repoDir}" ]; then
        print_error "Error: Directory ${repoDir} does not exist."
        exit 1
    fi
    # Ensure we are on the main branch
    currentBranch=$(cd ${repoDir} && git rev-parse --abbrev-ref HEAD)
    if [ "$currentBranch" != "main" ]; then
        echo
        print_error "⚠️ You are not on the main branch. Please switch to the main branch before running this script."
        echo "🔹 Press ENTER to continue on your current branch, or 'q' to quit: "
        # Read a single character, silently
        read -n 1 -s choice
        # Print what the user pressed
        echo

        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
            echo "Exiting..."
            echo
            exit 0
        fi
    fi
}

ensure_latest_commit_is_tagged() {
    if [ ${overrideTagBranchCheck} == "true" ]; then
        return
    fi
    repoDir=$1
    if [ ! -d "${repoDir}" ]; then
        print_error "Error: Directory ${repoDir} does not exist."
        exit 1
    fi
    # Ensure the latest commit is tagged
    latestTag=$(cd ${repoDir} && git describe --tags --abbrev=0)
    # If contains spaces, it's invalid or an error occurred
    if [[ "$latestTag" =~ \  ]]; then
        print_error "Error: Unable to find a valid tag in ${repoDir}. Please ensure the latest commit is tagged."
        exit 1
    fi
    latestCommit=$(cd ${repoDir} && git rev-parse HEAD)
    if [ "$(cd ${repoDir} && git rev-list -n 1 $latestTag)" != "$latestCommit" ]; then
        print_error "The latest commit is not tagged. Please tag the latest commit before running this script."
        echo "🔹 Press ENTER to continue on your commit, or 'q' to quit: "
        # Read a single character, silently
        read -n 1 -s choice
        # Print what the user pressed
        echo

        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
            echo "Exiting..."
            echo
            exit 0
        fi
    fi
}

create_release_on_github() {
    # If build type is not production, skip creating a release
    if [[ "${buildType}" != *production ]]; then
        print_notice "Skipping GitHub release creation for non-production build type."
        return
    fi
    if [ ${overrideTagBranchCheck} == "true" ]; then
        print_error "Skipping GitHub release creation due to overrideTagBranchCheck being true."
        return
    fi

    REPO=$1

    PLATFORM_TAG=`cd ${PLATFORM_REPO_DIR} && git tag --sort=-creatordate | head -n 1`

    # If the tag is empty print error
    if [ -z "${PLATFORM_TAG}" ]; then
        print_error "⚠️ Error: No tag found for platform repo. Please ensure the latest commit is tagged."
        return
    fi

    ${CORE_DIR}/scripts/create_github_release.sh ${OWNER} ${REPO} ${PLATFORM_TAG} ${PLATFORM_TAG}
}

run_main() {
    # set positional arguments in their proper places
    eval set -- "$PARAMS"

    check_commands_exist ${REQUIRED_CMDS[@]}

    if [ "$skipConfirmation" != "true" ]; then
        confirm_production_install
    fi

    set_server_user
    check_variable ${serverUser} "Server user didn't get defined. Reason: unknown."
    check_variable ${buildType} "Must specify a build type. Usage:"

    if [ ! -f "${sshIdentityFile}" ]; then
        print_error "⚠️ Error: identity file ${sshIdentityFile} not found"
        exit 1
    fi

    if ${backupPublicHtml} ; then
        backup_public_html
        exit 0
    fi

    if ${setPermissions} ; then
        change_ownership_and_permissions ${documentRoot}
        change_ownership_and_permissions ${domainRoot}/public_html_backups
        exit 0
    fi

    check_variable ${commandType} "Must specify a command type. Usage:"

    print_heading "\nRunning ${CORE_DIR}/scripts/install_release.sh"

    verify_files_and_dirs_exist

    print_settings

    if [[ $runFrontend == true || $runBackend == true ]]; then
        print_heading "\nBuilding frontend and backend..."
        cd ${PLATFORM_REPO_DIR} && npm run core build:production
    fi

    # Build the frontend and copy distribution files to public_html
    if [[ $runFrontend == true ]] ; then
        if [ "${commandType}" == "install" ]; then
            delete_frontend_old_server_files
            copy_frontend_to_server
            change_ownership_and_permissions ${documentRoot}
        fi
    fi

    # Copy backend files from repo to backend directory, update depends
    if [[ $runBackend == true ]] ; then
        if [ "${commandType}" == "install" ]; then
            delete_backend_old_server_files
            copy_backend_to_server
            change_ownership_and_permissions ${documentRoot}
            install_backend_composer_packages
            change_ownership_and_permissions ${documentRoot}
        fi
    fi

    if [ "${commandType}" == "createrelease" ]; then
        create_release_on_github "owoksape"
        exit 0
    fi
}

#------------------------------------------------------------------------------#
# Parse command-line arguments
#------------------------------------------------------------------------------#
while (( "$#" )); do
    case "$1" in
        -b|--backend)
            runBackend=true
            shift
            ;;
        --backup)
            backupPublicHtml=true
            shift
            ;;
        -c|--command)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                # if argument is one of the valid build types
                if [[ "${VALID_COMMANDS[@]}" =~ "$2" ]]; then
                    commandType=$2
                    shift 2
                else
                    print_error "⚠️ Error: Invalid command type: $2. Valid commands: ${VALID_COMMANDS[*]}"
                    exit 1
                fi
            else
                echo -e "⚠️ ${RED}Error: Argument for $1 is missing${COLOR_RESET}" >&2
                exit 1
            fi
            ;;
        --dryrun)
            dryRun=true
            shift
            ;;
        -f|--frontend)
            runFrontend=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 1
            ;;
        -i|--identity-file)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                # if file exists
                if [[ -f "$2" ]]; then
                    sshIdentityFile=$2
                    shift 2
                else
                    print_error "⚠️ Error: Identity file $2 not found"
                    exit 1
                fi
            else
                echo -e "⚠️ ${RED}Error: Argument for $1 is missing${COLOR_RESET}" >&2
                exit 1
            fi
            ;;
        -k|--skip-confirmation)
            skipConfirmation=true
            shift
            ;;
        -o|--override-tag-branch-check)
            overrideTagBranchCheck=true
            shift
            ;;
        -s|--set-permissions)
            setPermissions=true
            shift
            ;;
        -t|--build-type)
            # if 2nd argument is a string and its first character is not -
            # ${2:0:1} is Substring Expansion is the format ${parameter:offset:length}
            # (i.e., 2nd parameter, starting from character 0 grab 1 character),
            # so it grabs the first character of the 2 parameter in getopt.
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                # if argument is one of the valid build types
                if [[ "${VALID_BUILD_TYPES[@]}" =~ "$2" ]]; then
                    buildType=$2
                    shift 2
                else
                    print_error "⚠️ Error: Invalid build type: $2. Valid types: ${VALID_BUILD_TYPES[*]}"
                    exit 1
                fi
            else
                echo -e "⚠️ ${RED}Error: Argument for $1 is missing${COLOR_RESET}" >&2
                exit 1
            fi
            ;;
        -*|--*=) # unsupported flags
            print_error "⚠️ Error: Unsupported flag $1" >&2
            show_usage
            exit 1
            ;;
        *) # preserve positional arguments
            PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done

run_main

whatsInstalled=""
if [[ $runFrontend == true ]]; then
    whatsInstalled="frontend"
fi
if [[ $runBackend == true ]]; then
    if [[ -z "$whatsInstalled" ]]; then
        whatsInstalled="backend"
    else
        whatsInstalled="$whatsInstalled and backend"
    fi
fi

echo -e "${GREEN}The $commandType command for $buildType for the $whatsInstalled finished successfully${COLOR_RESET}"
