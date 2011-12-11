# Distribute Your Tests on the Cloud #

This project is still in the git-r-done state. Here's how you use it.

Set up your config file. You'll get most of these setting from your
Amazon account.

    cp config/cloud.yml.sample config/cloud.yml
    vi config/cloud.yml

Create your cluster.

    # stand up the master instance
    #
    rake cloud:master:create
    rake cloud:master:bootstrap
    rake cloud:master:chef
    rake cloud:master:sync
    rake cloud:master:bundle
    rake cloud:master:prepare_db

    # create an ami from your master instance
    #
    rake cloud:master:ami

    # create the cluster
    #
    rake cloud:cluster:create

Run your suite.

    rake hydra:test

After you make some changes to your working directory, make sure your cluster is up to date:

    rake cloud:cluster:sync
    rake cloud:cluster:bundle
    rake cloud:cluster:prepare_db

If something goes wrong, there are some tasks to help troubleshoot:

    # see what going on with the master instance
    #
    rake cloud:master:status
    rake cloud:master:ssh

    # see what going on with the cluster
    #
    rake cloud:cluster:status
    rake cloud:cluster:ssh
    rake cloud:cluster:load

Stopping, starting and cleaning up after yourself.

    rake cloud:master:start
    rake cloud:master:stop
    rake cloud:master:destroy

    rake cloud:cluster:start
    rake cloud:cluster:stop
    rake cloud:cluster:destroy
