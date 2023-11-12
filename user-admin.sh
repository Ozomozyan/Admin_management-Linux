#!/bin/bash

# Function to add a user
add_user() {
    read -p "Enter the username: " username
    if [[ -z "$username" ]]; then
        echo "Error: The username cannot be empty."
        return 1
    fi
    
    read -p "Enter the home directory path: " home_dir
    if [[ -z "$home_dir" ]]; then
        echo "Error: The home directory cannot be empty."
        return 2
    elif [[ -d "$home_dir" ]]; then
        echo "Error: The home directory already exists."
        return 3
    fi
    
    read -p "Enter the expiration date (YYYY-MM-DD): " exp_date
    if [[ -z "$exp_date" ]]; then
        echo "Error: The expiration date cannot be empty."
        return 4
    else
        # Convert the entered expiration date to seconds since epoch
        exp_date_sec=$(date -d "$exp_date" +%s)
        # Get today's date in seconds since epoch
        today_sec=$(date +%s)
        # Compare the two timestamps
        if [[ $exp_date_sec -lt $today_sec ]]; then
            echo "Error: The expiration date is before today."
            return 5
        fi
    fi

    
    read -s -p "Enter the password: " password
    echo
    if [[ -z "$password" ]]; then
        echo "Error: The password cannot be empty."
        return 6
    fi
    
    read -p "Enter the shell path: " shell
    if [[ -z "$shell" ]]; then
        echo "Error: The shell cannot be empty."
        return 7
    elif ! which "$shell" > /dev/null; then
        echo "Error: The shell is not installed."
        return 8
    fi
    
    read -p "Enter the user ID (UID): " uid
    if [[ -z "$uid" ]]; then
        echo "Error: The UID cannot be empty."
        return 9
    fi
    
    useradd -m -d "$home_dir" -e "$exp_date" -s "$shell" -u "$uid" -p "$(openssl passwd -1 "$password")" "$username"
    echo "User $username has been added successfully."
}

# Function to modify a user
modify_user() {
    read -p "Enter the username to modify: " username
    if id "$username" &>/dev/null; then
        echo "Modifying user '$username':"
        echo "1. Change username"
        echo "2. Change home folder path"
        echo "3. Change expiration date"
        echo "4. Change password"
        echo "5. Change shell"
        echo "6. Change UID (User ID)"
        read -p "Select what you want to modify [1-6]: " modify_choice

        case $modify_choice in
            1)
                read -p "Enter new username: " new_username
                if [[ -z "$new_username" ]]; then
                    echo "Error: The new username cannot be empty."
                    return 1
                fi
                # Check if a group with the same name as the user exists
                if grep -q "^${username}:" /etc/group; then
                    # Rename the group before renaming the user
                    if ! groupmod -n "$new_username" "$username"; then
                        echo "Error: Failed to rename the user's group."
                        return 1
                    fi
                fi
                # Change the username and rename group if it exists
                if usermod -l "$new_username" "$username"; then
                    echo "Username has been changed to $new_username"
                    # Check if user's home directory should also be renamed
                    if [[ -d "/home/${username}" ]]; then
                        mv "/home/${username}" "/home/${new_username}"
                        usermod -d "/home/${new_username}" -m "$new_username"
                    fi
                else
                    echo "Error: Failed to rename the user."
                    # If user renaming failed, revert the group name change
                    if grep -q "^${new_username}:" /etc/group; then
                        groupmod -n "$username" "$new_username"
                    fi
                    return 1
                fi
                ;;

            2)
                read -p "Enter new home folder path: " new_home
                if [[ -z "$new_home" ]]; then
                    echo "Error: The new home folder path cannot be empty."
                    return 2
                elif [ -d "$new_home" ]; then
                    echo "Error: The new home directory already exists."
                    return 3
                fi
                usermod -d "$new_home" -m "$username" && echo "Home folder path has been changed to $new_home"
                ;;
            3)
                read -p "Enter new expiration date (YYYY-MM-DD): " new_exp_date
                if [[ -z "$new_exp_date" ]]; then
                    echo "Error: The new expiration date cannot be empty."
                    return 4
                else
                    # Convert the entered expiration date to seconds since epoch
                    exp_date_sec=$(date -d "$new_exp_date" +%s)
                    # Get today's date in seconds since epoch
                    today_sec=$(date +%s)
                    # Compare the two timestamps
                    if [[ $exp_date_sec -lt $today_sec ]]; then
                        echo "Error: The expiration date is before today."
                        return 5
                    else
                        usermod -e "$new_exp_date" "$username" && echo "Expiration date has been changed."
                    fi
                fi
                ;;
            4)
                passwd "$username" && echo "Password has been changed for $username"
                ;;
            5)
                read -p "Enter new shell path: " new_shell
                if [[ -z "$new_shell" ]]; then
                    echo "Error: The new shell cannot be empty."
                    return 6
                elif ! [ -f "$new_shell" ]; then
                    echo "Error: The new shell does not exist."
                    return 7
                fi
                usermod -s "$new_shell" "$username" && echo "Shell has been changed to $new_shell"
                ;;
            6)
                read -p "Enter new UID: " new_uid
                if [[ -z "$new_uid" ]]; then
                    echo "Error: The new UID cannot be empty."
                    return 8
                elif ! [[ "$new_uid" =~ ^[0-9]+$ ]]; then
                    echo "Error: The UID must be a number."
                    return 9
                fi
                usermod -u "$new_uid" "$username" && echo "UID has been changed to $new_uid"
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    else
        echo "Error: User '$username' does not exist."
        return 10
    fi
}

# Function to delete a user
delete_user() {
    read -p "Enter the username to delete: " username
    if [[ -z "$username" || ! $(id "$username") ]]; then
        echo "Error: The user does not exist."
        return 11
    fi
    
    read -p "Delete the user's home directory? (yes/no): " del_home
    read -p "Force delete if the user is logged in? (yes/no): " force_del
    
    local userdel_arg=""
    if [[ "$del_home" == "yes" ]]; then
        userdel_arg="-r"
    fi
    
    if [[ "$force_del" == "yes" ]]; then
        userdel_arg+=" -f"
    fi
    
    userdel $userdel_arg "$username"
    echo "User $username has been deleted."
}


# Function to add user to the sudoers
add_to_sudoers() {
    read -p "Enter username to add to sudoers: " username
    if id "$username" &>/dev/null; then
        usermod -aG sudo "$username" && echo "User '$username' has been added to sudoers."
    else
        echo "Error: User '$username' does not exist."
    fi
}

# Function to remove user from the sudoers
remove_from_sudoers() {
    read -p "Enter username to remove from sudoers: " username
    if id "$username" &>/dev/null; then
        gpasswd -d "$username" sudo && echo "User '$username' has been removed from sudoers."
    else
        echo "Error: User '$username' does not exist."
    fi
}

# Function to add users from a file
add_users_from_file() {
    read -p "Enter the filename with user details: " filename
    if [[ -f "$filename" ]]; then
        while IFS=: read -r username password expiry_date shell UID; do
            add_user_from_file "$username" "$password" "$expiry_date" "$shell" "$UID"
        done < "$filename"
    else
        echo "Error: File does not exist."
    fi
}

add_user_from_file() {
    local username="$1"
    local password="$2"
    local expiry_date="$3"
    local shell="$4"
    local UID="$5"
    local home_directory="/home/$username"  # Assuming a standard home directory

    # Check for required fields, adjust these checks as per your exact requirements
    if [[ -z "$username" ]]; then
        echo "Error: Username is empty."
        return 1
    fi

    if [[ -z "$home_directory" ]] || [[ -d "$home_directory" ]]; then
        echo "Error: Home directory is empty or already exists."
        return 1
    fi

    if [[ -z "$expiry_date" ]] || ! date -d "$expiry_date" &>/dev/null; then
        echo "Error: Expiry date is empty or invalid."
        return 1
    fi

    if [[ -z "$shell" ]] || ! which "$shell" &>/dev/null; then
        echo "Error: Shell is empty or not installed."
        return 1
    fi

    # Check if the UID is already in use
    if ! getent passwd "$UID" &>/dev/null; then
        # Create the user with the provided details
        useradd -m -d "$home_directory" -s "$shell" -e "$expiry_date" -u "$UID" "$username" && \
        echo "$username:$password" | chpasswd

        if [[ $? -eq 0 ]]; then
            echo "User '$username' added successfully."
        else
            echo "Error: Failed to add user '$username'."
            return 1
        fi
    else
        echo "Error: UID '$UID' is already in use."
        return 1
    fi
}


while true; do
    echo "Select an option:"
    echo "1. Add a user"
    echo "2. Modify a user"
    echo "3. Delete a user"
    echo "4. Add user to sudoers"
    echo "5. Remove user from sudoers"
    echo "6. Add users from a file"
    echo "7. Exit"
    read -p "Enter your choice [1-7]: " choice

    case $choice in
        1) add_user ;;
        2) modify_user ;;
        3) delete_user ;;
        4) add_to_sudoers ;;
        5) remove_from_sudoers ;;
        6) add_users_from_file ;;
        7) echo "Exiting the script."
           exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
