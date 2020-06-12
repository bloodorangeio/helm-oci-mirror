*** Settings ***
Documentation     Test helm-oci-mirror
Library           String
Library           OperatingSystem
Library           lib/Sh.py

*** Test Cases ***
Works as a helm plugin
    Helm setup
    Can be installed as a Helm plugin
    Is listed as a Helm plugin after install
    Can be run as a Helm plugin
    Can be removed
    Is not listed as a Helm plugin after removal

*** Keywords ***
Helm setup
    Should pass         helm plugin remove oci-mirror || true

Can be installed as a Helm plugin
    Should pass         helm plugin install \$\{PWD\}

Is listed as a Helm plugin after install
    Should pass         helm plugin list | grep ^oci-mirror

Can be run as a Helm plugin
    Should pass         helm oci-mirror --help

Can be removed
    Should pass         helm plugin remove oci-mirror

Is not listed as a Helm plugin after removal
    Should fail         helm plugin list | grep ^oci-mirror