#!/usr/bin/env bash

# On login get the logging in IP from PAM_RHOST
# Check if the user has active sessions
#	- If YES then compare the connected IPs
#		- Compare PAM_RHOST to IP's connected. If PAM_RHOST != connected_ip then log user out
#	- If NO then log them in

# Logging in user
user="${PAM_USER}"

# Logging in event 
event="${PAM_TYPE}"

#
# Email notification
#
# * TBD: Maybe expand this and "find out" what mail command we want to use?
#
function mail_event() {
        local sender="sender@domain.com"
        local recepient="recevier@domain.com"
	if [ -z $(command -v mailx) ]; then
		return
	fi
        echo "$@" | mailx -r "${sender}" -s "${event}" "${recepient}"
}


#
# We dont always get an IP from PAM_RHOST. When we WONT is when DNS is failing or sshd is
# configured with UseDNS no. Since its assumed the system will have ping then we 
# ping it and parse ping. Its crappy but it works. We need IP to pass to 'w' command
# for counting logins
#
# * TBD: Find better way to resolve IP with less reliance on external tools
#
function get_connected_ip() {
	local ip=1
	is_pam_rhost_ip=$( echo "${PAM_RHOST}" | grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | wc -l)
	if [ ${is_pam_rhost_ip} -eq 1 ]; then
		ip="${PAM_RHOST}"
	else
		ip=$( ping -w .1 -c 1 ${PAM_RHOST} |  grep PING | awk '{ print $3 }' | sed 's,(\|),,g' )
	fi
	echo "${ip}"
}

# Get their IP
user_ip=$(get_connected_ip)
echo "${user} / ${event} / ${user_ip}"

# Function to return # of logins
function count_user_current_logins() {
	echo $(w -h -i ${user} | grep ${user_ip} | wc -l)
}


# Called when pam calls open_session
function on_open_session() {

	user_sessions=$( w -h -u ${user} | wc -l)
	echo "User sessions is ${user_sessions}"	
	
	# If this is their first session then just let them in
	if [ ${user_sessions} -eq 0 ]; then
		echo "welcome! You have no other sessions so come on in!"
	else
		#else if its NOT then we need to do some logic handling
		echo "WAIT! You have other sessions. Lets see if you're connecting host doesnt match any connected hosts"
		
		# Take their logging in IP and check it against current accessed list
		login_list_nomatch=$(w -h -u ${user} -i | grep -v ${user_ip} | wc -l )
		
		# If we get a result > 0 then we have an existing session from another ip
		if [ ${login_list_nomatch} -gt 0 ]; then
			echo "SORRY! You are connected from ${login_list_nomatch} other IPs"
			exit 2
		else
			echo "OK! You're connecting from an already connected IP. Go for it! count = ${login_list_nomatch}"
		fi
			
	fi
	mail_event "DBG:on_open_session: User has ${user_sessions} active from IP ${user_ip}"
}

# Called when PAM calls close_session
function on_close_session() {
	local user_sessions=$(count_user_current_logins)
	mail_event "DBG:on_close_session: User has ${user_sessions} active from IP ${user_ip}"

}

# Loop the PAM event passed in
case "${event}" in
	open_session)
		on_open_session
	;;
	close_session)
		on_close_session
	;;
	*)
		mail_event "unhandled event ${event}"
	;;
esac
