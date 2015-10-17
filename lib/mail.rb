require "net/smtp"

# Quick method to send mail on problems

FROM = '"LDAP Sync" <ldapsync@ldap-sync.example.org>' 
UNIX = '"Alert" <alert@example.edu>' 

def mail_on_updates(updates)
  subject = "Update threshold reached"
  body =<<EOM
Uncomment sync.rb in crontab and investigate.
We were about to update #{updates.length}.

Pending updates:
EOM

  updates.each_pair do |name, entry|
    body << "#{name}: #{entry.inspect}\n"
  end

  mail(UNIX, subject, body)
end


def mail_on_deletes(deletes)
  subject = "Deletion threshold reached"
  body =<<EOM
Uncomment sync.rb in crontab and investigate.
We were about to delete #{deletes.length}.

Pending deletions:
EOM

  deletes.each_pair do |name, entry|
    body << "#{name}: #{entry.inspect}\n"
  end

  mail(UNIX, subject, body)
end

def mail_on_lock
  subject = "Lockfile reached"
  body = "The lockfile was reached"
  mail(UNIX, subject, body)
end


def mail(to, subject, body)
  message =<<EOM
From: #{FROM}
To: #{to}
Subject: #{subject}

#{body}

EOM

  Net::SMTP.start("localhost") do |smtp|
    smtp.send_message(message, FROM, to)
  end
end
