ARG IMAGE=containers.intersystems.com/intersystems/irishealth-community:2026.2
FROM ${IMAGE}
USER root
COPY --chown=irisowner:irisowner src /opt/fhir-openapi/src
COPY --chown=irisowner:irisowner web /opt/fhir-openapi/web
COPY --chown=irisowner:irisowner scripts/install.script /opt/fhir-openapi/install.script
USER irisowner
RUN iris start IRIS \
    && iris session IRIS -U USER < /opt/fhir-openapi/install.script > /tmp/fhir-openapi-install.log \
    && cat /tmp/fhir-openapi-install.log \
    && grep -q FHIR_OPENAPI_INSTALL_OK /tmp/fhir-openapi-install.log \
    && iris stop IRIS quietly
