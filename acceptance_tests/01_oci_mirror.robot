*** Settings ***
Documentation     Test helm-oci-mirror
Library           String
Library           OperatingSystem
Library           lib/Sh.py

*** Test Cases ***
Helm oci mirror
    Helm setup
    Run oci mirror
    Helm pull new chart

*** Keywords ***
Helm setup
    Should pass         helm repo add chartmuseum http://localhost:\$\{CHARTMUSEUM_PORT\}
    Should pass         helm repo update

Run oci mirror
    Should pass         oci-mirror --debug chartmuseum localhost:\$\{DISTRIBUTION_PORT\}/u/acceptance

Helm pull new chart
    Should pass         helm chart pull localhost:\$\{DISTRIBUTION_PORT\}/u/acceptance/\$\{CHART_NAME_A\}:0.1.0
