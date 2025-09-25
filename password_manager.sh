#!/usr/bin/env bash

PASSWORD_FILE="passwords.enc"
PASSPHRASE_FILE=".passphrase.hash"

check_xclip_installed() {
	if ! command -v xclip &> /dev/null
	then
		echo "Warning: 'xclip' is not installed. Please run:"
		echo "	sudo apt update && sudo apt install xclip"
		echo " "
	fi
}

start_up() {
	if [ ! -f $PASSPHRASE_FILE ]
	then
		echo "--- Welcome to your password manager! ---"
		echo " "
		echo "It looks like you are new here... worry not!"
		echo "Let's get you set up. All you need to do is set a master passphrase."
		echo "You will use this to access all your passwords so make it secure and memorable!"
		echo "Please enter your master passphrase: "
		read -s PASSPHRASE
		echo "Enter the master passphrase AGAIN: "
		read -s CONFIRM_PASSPHRASE
		PASS_LENGTH=${#PASSPHRASE}
		if [ $CONFIRM_PASSPHRASE != $PASSPHRASE ]
		then
			echo "Passphrase does not match. Exiting..."
			exit 1
		fi
		echo "Saving passphrase..."
		echo -n $PASSPHRASE | sha256sum > .passphrase.hash
		chmod 600 .passphrase.hash
		touch passwords.enc
		echo "Success! You are now set up..."
		echo " "
		echo "--- Welcome to your password manager! ---"
		check_passphrase
		menu
	else
		echo "--- Welcome to your password manager! ---"
		check_passphrase
		menu
	fi
}

menu() {
	echo " "
	echo "1. Add Password"
	echo "2. View Password"
	echo "3. Delete Password"
	echo "4. Update Master Passphrase"
	echo "5. Exit"
	read -p "Choose an option: " CHOICE
	if [ $CHOICE -eq 1 ]
	then
		add_password
	elif [ $CHOICE -eq 2 ]
	then
		view_password
	elif [ $CHOICE -eq 3 ]
	then
		delete_password
	elif [ $CHOICE -eq 4 ]
	then
		update_passphrase 
	elif [ $CHOICE -eq 5 ]
	then
		echo "Exiting..."
		exit 0
	else 
		echo "Invalid option. Exiting..."
		exit 1
	fi
}

check_passphrase() {
	local ACTUAL_HASH=$(<.passphrase.hash)
	local COUNT=0
	while [ $COUNT -le 2 ]
	do
		echo "Please enter your master passphrase: "
		read -s PASSPHRASE
		local NEW_HASH=$(echo -n $PASSPHRASE | sha256sum)
		if [[ "$ACTUAL_HASH" == "$NEW_HASH" ]]
		then
			break
		else
			((COUNT++))
			echo "Oops! Master passphrase did not match. Try again ($COUNT/3)"
		fi
	done
	if [ $COUNT -eq 3 ]
	then
		echo "Master passphrase is incorrect! Exiting..."
		exit 1
	fi
}

update_passphrase() {
	echo "--- Confirm master passphrase ---"
	check_passphrase
	echo "Please enter your NEW master passphrase: "
	read -s PASSPHRASE
	echo "Enter new master passphrase AGAIN: "
	read -s CONFIRM_PASSPHRASE
	PASS_LENGTH=${#PASSPHRASE}
	if [ $CONFIRM_PASSPHRASE != $PASSPHRASE ]
	then
		echo "Passphrase does not match. Exiting..."
		exit 1
	fi
	echo -n $PASSPHRASE | sha256sum > .passphrase.hash
	echo "New master passphrase set!"
	menu
}

add_password() {
	get_current_services
	if [ ! ${#ALL_ENTRIES[@]} -eq 0 ]
	then
		show_current_services
		read -p "Enter NEW service name: " SERVICE
		while IFS='' read -r LINE
		do
			local SVC=$(echo $LINE | cut -d'|' -f1 | xargs)
			if [ $SVC = $SERVICE ]
			then
				echo "There is already a password stored for $SERVICE!"
				exit 1
			fi
		done <<< $ALL_ENTRIES
	else
		read -p "Enter NEW service name: " SERVICE
	fi
	read -p "Enter user name: " USER
	read -p "Would you like to randomly generate a secure password? (Y/N): " GENERATE_RANDOM
	if [ $GENERATE_RANDOM = "N" ]
	then
		echo "Passwords must contain at least 1 digit and 1 special character."
		echo "Passwords should ideally be at least 12 characters long."
		read -p "Enter password: " PASSWORD
		read -p "Confirm by entering password again: " CONFIRM_PASS
		PASS_LENGTH=${#PASSWORD}
		if [ $CONFIRM_PASS != $PASSWORD ]
		then
			echo "Password does not match. Please enter the same password to confirm."
			echo "Exiting..."
			exit 1
		elif [[ ! $PASSWORD =~ ['0-9'] ]]
		then
			echo "Password does not contain any digits. Please try again."
			echo "Exiting..."
			exit 1
		elif [[ ! $PASSWORD =~ ['!@#$%^&*()_+='] ]]
		then
			echo "Password does not contain any special characters. Please try again."
			echo "Exiting..."
			exit 1
		elif [ $PASS_LENGTH -lt 12 ]
		then
			echo "Warning: password is less than 12 characters long."
			read -p "Do you wish to proceed? (Y/N): " PROCEED
			if [ ! $PROCEED = "Y" ]
			then
				echo "Adding password cancelled."
				exit 1
			fi
		fi 
	elif [ $GENERATE_RANDOM = "Y" ]
	then
		generate_password
	else
		echo "Invalid option entered. Exiting..."
	fi
	encrypt_password
	menu
}

delete_password() {
	get_current_services
	if [ ! ${#ALL_ENTRIES[@]} -eq 0 ]
	then
		show_current_services
		read -p "Enter service name: " SERVICE
		read -p "Are you sure you'd like to delete $SERVICE? (Y/N): " PROCEED
		if [ ! $PROCEED = "Y" ]
			then
				echo "Deleting password cancelled."
				exit 1
			fi
		echo "Deleting password..."
		openssl enc -aes-256-cbc -d -pbkdf2 -in $PASSWORD_FILE -pass pass:$PASSPHRASE -out temp.txt
		grep -v "^${SERVICE}[[:space:]]*|" temp.txt > temp_cleaned.txt
		openssl enc -aes-256-cbc -salt -pbkdf2 -in temp_cleaned.txt -out $PASSWORD_FILE -pass pass:$PASSPHRASE
		rm temp.txt
		rm temp_cleaned.txt
	fi
	echo "Password successfully deleted!"
	menu
}

generate_password() {
	PASSWORD=`openssl rand -base64 12 | tr -dc 'A-Za-z0-9!@#$%^&*()_+=' | head -c12`
	echo "Password successfully generated!"
}

encrypt_password() {
	get_current_services
	local NEW_ENTRY="$SERVICE | $USER | $PASSWORD"
	if [ ! ${#ALL_ENTRIES[@]} -eq 0 ]
	then
		openssl enc -aes-256-cbc -d -pbkdf2 -in $PASSWORD_FILE -pass pass:$PASSPHRASE -out temp.txt
	else
		touch temp.txt
	fi
	echo $NEW_ENTRY >> temp.txt
	openssl enc -aes-256-cbc -salt -pbkdf2 -in temp.txt -out $PASSWORD_FILE -pass pass:$PASSPHRASE
	rm temp.txt
	echo "Password saved!"
}

get_current_services() {
	if [ -s "$PASSWORD_FILE" ]
	then
		ALL_ENTRIES=$(openssl enc -aes-256-cbc -d -pbkdf2 -in $PASSWORD_FILE -pass pass:$PASSPHRASE)
	else
		ALL_ENTRIES=()
		echo "Password manager is empty."
	fi
}

show_current_services() {
	echo "Service names already stored:"
	while IFS='' read -r LINE
	do
		echo $LINE | cut -d'|' -f1 | xargs
	done <<< $ALL_ENTRIES
}

view_password() {
	get_current_services
	if [ ! ${#ALL_ENTRIES[@]} -eq 0 ]
	then
		show_current_services
		read -p "Enter service name: " SERVICE_NAME
		while IFS='' read -r LINE
		do
			local SVC=$(echo $LINE | cut -d'|' -f1 | xargs)
			if [ $SVC = $SERVICE_NAME ]
			then
				local USERNAME=$(echo $LINE | cut -d'|' -f2 | xargs)
				echo "User name: $USERNAME"
				local PASSWORD=$(echo $LINE | cut -d'|' -f3 | xargs)
				echo "Adding password to clipboard..."
				echo -n $PASSWORD | xclip -selection clipboard
			fi
		done <<< $ALL_ENTRIES
	fi
	menu
}

check_xclip_installed
start_up
exit 0
