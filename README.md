eawsudo + aws-agent
==================

Overview
------------

**eawsudo** enables users to execute commands that make API calls to AWS under
the security context of an IAM role. The IAM role is assumed only upon
successful authentication against a SAML compliant federation service.

**aws-agent** enables users to authenticate against a SAML compliant federation
service once, after which aws-agent provides temporary credentials to eawsudo
to use.

Synopsis
------------

      eawsudo {role-name | role-arn} command
     
      aws-agent
     
Requirements
------------

  * UNIX, UNIX-like or GNU/Linux operating system
  * SAML compliant federation service
  * ruby 1.9 or above
  * ruby gems: aws-sdk

Install
------------

      git clone https://github.com/electronicarts/eawsudo.git
      cd eawsudo
      gem build eawsudo.gemspec
      sudo gem install eawsudo-<version>.gem

Configuration
------------

eawsudo and aws-agent expect a configuration file named .awsudo in your home directory
containing the values for your identity provider login url and the SAML provider name
configured in AWS. This is an example, your setup may vary:

      IDP_LOGIN_URL = https://sts.example.com/adfs/ls/IdpInitiatedSignOn.aspx?loginToRp=urn:amazon:webservices
      SAML_PROVIDER_NAME = ADFS

In addition to .eawsudo, you can create .aws-roles in your home directory to map
IAM roles ARNs to more easy to remember alias names, one per line, separated by spaces. Example:

      myaccount-admin  arn:aws:iam::123456789012:role/myaccount-admin
 
Examples
------------

### eawsudo

      $ eawsudo arn:aws:iam::123456789012:role/myaccount-admin aws ec2 describe-tags --region us-west-2
    
      $ eawsudo myaccount-admin aws ec2 describe-instances --region us-east-1

eawsudo will ask your federated credentials every time. To avoid this use aws-agent as follows:

### aws-agent

      $ aws-agent
      Login: username
      Password:
      AWS_AUTH_SOCK=/var/folders/xz/lx178g0d0rb36x95446zwgd80000gp/T/aws-20150623-20990-58v1c4/agent; export AWS_AUTH_SOCK;

then execute the commands printed by aws-agent. eawsudo will now ask for temporary credentials to aws-agent.

Author
-------

[Gerardo Santana Gomez Garrido](https://github.com/santana)

Contributors
-------------
  * [Matthew Wygant](https://github.com/mkwygant)
  * [Ivan Zenteno](https://github.com/k001)
  * [David Hannon](https://github.com/dhannon)
