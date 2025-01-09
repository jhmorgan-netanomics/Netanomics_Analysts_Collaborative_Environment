#!/bin/bash

# Debug: Print the current user and DISPLAY
echo "DEBUG: Current DISPLAY is: '${DISPLAY}'"
echo "DEBUG: Current user is: $(whoami)"

# Ensure Git is configured globally for the container
if ! git config --global user.name &> /dev/null; then
    echo "Git user.name is not set. Please enter your Git username:"
    read git_user_name
    git config --global user.name "$git_user_name"
fi

if ! git config --global user.email &> /dev/null; then
    echo "Git user.email is not set. Please enter your Git email:"
    read git_user_email
    git config --global user.email "$git_user_email"
fi

# Initialize the default user variable
created_user=""

# Prompt to create a user if 'netanomics' doesn't exist
if ! id -u netanomics &>/dev/null; then
    echo "No 'netanomics' user found. Please create an account."

    # Prompt for username
    while true; do
        echo -n "Enter the username for the new account: "
        read new_user
        if [[ -z "$new_user" ]]; then
            echo "Username cannot be empty. Please try again."
        else
            break
        fi
    done

    # Prompt for password
    while true; do
        echo -n "Enter the password for the new account: "
        read -s new_password
        echo
        if [[ -z "$new_password" ]]; then
            echo "Password cannot be empty. Please try again."
        else
            break
        fi
    done

    # Create the user and set the password
    useradd -m "$new_user"
    echo "$new_user:$new_password" | chpasswd

    # Add the user to the sudo group
    usermod -aG sudo "$new_user"
    echo "$new_user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

    # Use update_rstudio.sh to update the configuration
    echo "Updating RStudio Server configuration with the new user..."
    /usr/local/bin/update_rstudio.sh "$new_user"

    echo "Account '$new_user' created and configured for RStudio Server."
    created_user="$new_user"
else
    created_user="netanomics"

    # Use update_rstudio.sh to ensure the configuration is correct
    echo "Ensuring RStudio Server is configured for existing user '$created_user'..."
    /usr/local/bin/update_rstudio.sh "$created_user"
fi

# Start the workflow
if [ "$1" == "rstudio" ]; then
    echo "Starting RStudio Server..."
    /usr/local/bin/start_rstudio_server.sh "$created_user"
elif [ "$1" == "jupyter" ]; then
    echo "Starting JupyterLab..."
    /usr/local/bin/start_jupyterlab.sh
elif [ -n "$DISPLAY" ]; then
    echo "Using existing DISPLAY: $DISPLAY"
    openbox &
    exec /bin/bash
else
    echo "No DISPLAY found. Starting a basic interactive shell..."
    exec /bin/bash
fi
