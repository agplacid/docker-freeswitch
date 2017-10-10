import os
import glob

from invoke import Collection, task

from . import test, dc, kube


COLLECTIONS = [test, dc, kube]

ns = Collection()
for c in COLLECTIONS:
    ns.add_collection(c)


ns.configure(dict(
    project='freeswitch',
    repo='docker-freeswitch',
    pwd=os.getcwd(),
    docker=dict(
        user=os.getenv('DOCKER_USER'),
        org=os.getenv('DOCKER_ORG', os.getenv('DOCKER_USER', 'telephoneorg')),
        name='freeswitch',
        tag='%s/%s:latest' % (
            os.getenv('DOCKER_ORG', os.getenv('DOCKER_USER', 'telephoneorg')), 'freeswitch'
        ),
        shell='bash'
    ),
    kube=dict(
        environment='testing'
    )
))
