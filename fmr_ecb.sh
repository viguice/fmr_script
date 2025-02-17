#!/bin/bash

function runPreCheck {
  echo "... Running pre-check"

  echo -n "...... Docker installed? "
  if [ -z "$(command -v docker)" ]; then
    echo "No! You are trying to install a DOCKER image. 'docker' is not installed."
    exit 1
  else
    echo " OK"
  fi


  echo -n "...... jq installed? "
  if [ -z "$(command -v jq)" ]; then
    echo "'yq' not found on system. Using leplusorg/xml:latest image."
    jq () {
    docker run -i --rm leplusorg/xml:latest jq "$@"
    }   
  else
    echo " OK"
  fi

  # Check if xmlstarlet is installed
  if [ -z "$(command -v xmlstarlet)" ]; then
      echo "xmlstarlet not found on system. Using leplusorg/xml:latest to proceed."
      docker image pull leplusorg/xml:latest
      xmlstarlet () {
      #var=${@/$temp_file/\/tmp\/data.xml}
      MSYS_NO_PATHCONV=1 docker run -i -v "/$PWD":/home/default --rm leplusorg/xml:latest xmlstarlet "$@"
      #echo "<----DOCKER"
      } 
  fi

}

function docker_start {
  # Check if the container exists
  if docker inspect "$1" > /dev/null 2>&1; then
      echo "The container $1 exists."
      
      # Check if the container is running
      if $(docker inspect -f '{{.State.Status}}' "$1" | grep -q "running"); then
          echo "The container $1 is running."
      else
          echo "The container $1 is not running."
          
          # Start the container if it is not running
          docker start "$1"
      fi
  else
      echo "The container $1 does not exist."
      
      # Create and start the container if it does not exist
      docker run -d --name "$@"
  fi
}

# Function to transform SubmissionResult to table
function SubmissionResult_to_table {

  # Extract submission results into a table format
  # Issue using git bash on windows
  #temp_file=$(mktemp)
  temp_file="./data.xml"
  echo "$@" > "$temp_file"
 MSYS_NO_PATHCONV=1 xmlstarlet sel \
    -N reg='http://www.sdmx.org/resources/sdmxml/schemas/v2_1/registry' \
    -N message='http://www.sdmx.org/resources/sdmxml/schemas/v2_1/message' \
    -N com='http://www.sdmx.org/resources/sdmxml/schemas/v2_1/common' \
    -t \
    -o 'Action|URN|Status' \
    -m '//reg:SubmissionResult' \
    -n \
    -v 'concat(reg:SubmittedStructure/@action, "|", reg:SubmittedStructure/reg:MaintainableObject/URN, "|", reg:StatusMessage/@status)' \
    "$temp_file" | column -t -s '|'
    rm "$temp_file"
}


runPreCheck
docker_start fmr -p 8080:8080 -e SERVER_URL=http://localhost:8080 -eCATALINA_OPTS="-Xmx6G" sdmxio/fmr-mysql:11.19.4
until curl --output /dev/null --silent --head --fail http://localhost:8080/ws/fusion/info/product; do
    printf '.'
    sleep 5
done


# Not working: What is the correct syntax for using an URL (possible with the GUI)?
# curl -X POST http://localhost:8080/ws/secure/sdmxapi/rest \
#   --header "Content-Type:application/xml" \
#   --user root:password \
#   -F "uploadUrl=https://data-api.ecb.europa.eu/service/datastructure/all/all/all?references=all" \
#   -F "uploadFile=" \
#   -F "publishAction=replace" \
#   -F "load=" \
#   -F "fileName=" \
#   -F "uploadType=url"

# Working with pipe (but not fully support asynchron process)
# curl https://data-api.ecb.europa.eu/service/datastructure/all/all/all?references=all | \
#   curl -X POST \
#     --user root:password \
#     --header "Content-Type: application/xml" \
#     --data-binary @- \
#      http://localhost:8080/ws/secure/sdmxapi/rest
xml_content=$(curl -s https://registry.sdmx.org/sdmx/v2/structure/codelist/SDMX/CL_FREQ/+/?format=sdmx-3.0 | \
  curl -s -X POST \
    --user root:password \
    --header 'Content-Type: application/xml' \
    --header 'Action: Replace' \
    --data-binary @- \
     http://localhost:8080/ws/secure/sdmxapi/rest)
SubmissionResult_to_table "$xml_content"


# Discrepancies in structures stored as examples in docker image -> update with current version...
xml_content=$(curl -s https://data-api.ecb.europa.eu/service/datastructure/ECB/ECB_EXR1/1.0?references=all | \
  curl -s -X POST \
    --user root:password \
    --header 'Content-Type: application/xml' \
    --header 'Action: Replace' \
    --data-binary @- \
     http://localhost:8080/ws/secure/sdmxapi/rest)
SubmissionResult_to_table "$xml_content"

xml_content=$(curl -s https://data-api.ecb.europa.eu/service/datastructure/ECB/ECB_TRD1/1.0?references=all | \
  curl -s -X POST \
    --user root:password \
    --header 'Content-Type: application/xml' \
    --header 'Action: Replace' \
    --data-binary @- \
     http://localhost:8080/ws/secure/sdmxapi/rest)
SubmissionResult_to_table "$xml_content"


additional_content=$(cat <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<message:Structure xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xml="http://www.w3.org/XML/1998/namespace"
  xmlns:message="http://www.sdmx.org/resources/sdmxml/schemas/v3_0/message"
  xmlns:str="http://www.sdmx.org/resources/sdmxml/schemas/v3_0/structure"
  xmlns:com="http://www.sdmx.org/resources/sdmxml/schemas/v3_0/common">
  <message:Header>
    <message:ID>IREF359423</message:ID>
    <message:Test>false</message:Test>
    <message:Prepared>2025-02-14T12:25:49Z</message:Prepared>
    <message:Sender id="Unknown"/>
    <message:Receiver id="not_supplied"/>
  </message:Header>
  <message:Structures>
    <str:DataConstraints>
      <str:DataConstraint urn="urn:sdmx:org.sdmx.infomodel.registry.DataConstraint=SDMX:CR_EXR_A(1.0)" role="Allowed" isExternalReference="false" agencyID="SDMX" id="CR_EXR_A" version="1.0">
        <com:Name xml:lang="en">EXR Annual</com:Name>
        <str:ConstraintAttachment>
          <str:Dataflow>urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=SDMX:EXR_A(1.0)</str:Dataflow>
        </str:ConstraintAttachment>
        <str:CubeRegion include="true">
          <str:KeyValue id="FREQ">
            <str:Value>A</str:Value>
          </str:KeyValue>
        </str:CubeRegion>
      </str:DataConstraint>
    </str:DataConstraints>
    <str:Dataflows>
      <str:Dataflow urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=SDMX:EXR(1.0)" isExternalReference="false" agencyID="SDMX" id="EXR" version="1.0">
        <com:Name xml:lang="en">Exchange Rates</com:Name>
        <str:Structure>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_EXR1(1.0)</str:Structure>
      </str:Dataflow>
      <str:Dataflow urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=SDMX:EXR_A(1.0)" isExternalReference="false" agencyID="SDMX" id="EXR_A" version="1.0">
        <com:Name xml:lang="en">Exchange Rates (Annual)</com:Name>
        <str:Structure>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_EXR1(1.0)</str:Structure>
      </str:Dataflow>
      <str:Dataflow urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=SDMX:TRD(1.0)" isExternalReference="false" agencyID="SDMX" id="TRD" version="1.0">
        <com:Name xml:lang="en">External Trade</com:Name>
        <str:Structure>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_TRD1(1.0)</str:Structure>
      </str:Dataflow>
    </str:Dataflows>
    <str:DataStructures>
      <str:DataStructure urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_EXR1(1.0)" isExternalReference="false" agencyID="SDMX" id="ECB_EXR1" uri="https://www.ecb.europa.eu/vocabulary/stats/exr/1" version="1.0">
        <com:Name xml:lang="en">Exchange Rates</com:Name>
        <str:DataStructureComponents>
          <str:DimensionList urn="urn:sdmx:org.sdmx.infomodel.datastructure.DimensionDescriptor=SDMX:ECB_EXR1(1.0).DimensionDescriptor" id="DimensionDescriptor">
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_EXR1(1.0).FREQ" id="FREQ" position="1">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).FREQ</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=SDMX:CL_FREQ(2.1)</str:Enumeration>
                <str:EnumerationFormat textType="String"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_EXR1(1.0).CURRENCY" id="CURRENCY" position="2">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).CURRENCY</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_CURRENCY(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="3"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_EXR1(1.0).CURRENCY_DENOM" id="CURRENCY_DENOM" position="3">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).CURRENCY_DENOM</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_CURRENCY(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="3"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_EXR1(1.0).EXR_TYPE" id="EXR_TYPE" position="4">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).EXR_TYPE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_EXR_TYPE(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="4" textType="String" maxLength="4"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_EXR1(1.0).EXR_SUFFIX" id="EXR_SUFFIX" position="5">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).EXR_SUFFIX</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_EXR_SUFFIX(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:TimeDimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.TimeDimension=SDMX:ECB_EXR1(1.0).TIME_PERIOD" id="TIME_PERIOD">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TIME_PERIOD</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="ObservationalTimePeriod"/>
              </str:LocalRepresentation>
            </str:TimeDimension>
          </str:DimensionList>
          <str:Group urn="urn:sdmx:org.sdmx.infomodel.datastructure.GroupDimensionDescriptor=SDMX:ECB_EXR1(1.0).Group" id="Group">
            <str:GroupDimension>
              <str:DimensionReference>CURRENCY</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>CURRENCY_DENOM</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>EXR_TYPE</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>EXR_SUFFIX</str:DimensionReference>
            </str:GroupDimension>
          </str:Group>
          <str:AttributeList urn="urn:sdmx:org.sdmx.infomodel.datastructure.AttributeDescriptor=SDMX:ECB_EXR1(1.0).AttributeDescriptor" id="AttributeDescriptor">
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).TIME_FORMAT" usage="mandatory" id="TIME_FORMAT">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TIME_FORMAT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="3"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).OBS_STATUS" usage="mandatory" id="OBS_STATUS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_STATUS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_OBS_STATUS(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).OBS_CONF" usage="optional" id="OBS_CONF">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_CONF</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_OBS_CONF(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).OBS_PRE_BREAK" usage="optional" id="OBS_PRE_BREAK">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_PRE_BREAK</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="30"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).OBS_COM" usage="optional" id="OBS_COM">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_COM</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).BREAKS" usage="optional" id="BREAKS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).BREAKS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="350"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).COLLECTION" usage="mandatory" id="COLLECTION">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COLLECTION</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_COLLECTION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).COMPILING_ORG" usage="optional" id="COMPILING_ORG">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COMPILING_ORG</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ORGANISATION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="6"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).DISS_ORG" usage="optional" id="DISS_ORG">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).DISS_ORG</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ORGANISATION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="6"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).DOM_SER_IDS" usage="optional" id="DOM_SER_IDS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).DOM_SER_IDS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="70"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).PUBL_ECB" usage="optional" id="PUBL_ECB">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).PUBL_ECB</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).PUBL_MU" usage="optional" id="PUBL_MU">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).PUBL_MU</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).PUBL_PUBLIC" usage="optional" id="PUBL_PUBLIC">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).PUBL_PUBLIC</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).UNIT_INDEX_BASE" usage="optional" id="UNIT_INDEX_BASE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).UNIT_INDEX_BASE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="35"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).COMPILATION" usage="optional" id="COMPILATION">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COMPILATION</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).COVERAGE" usage="optional" id="COVERAGE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COVERAGE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="350"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).DECIMALS" usage="mandatory" id="DECIMALS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).DECIMALS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_DECIMALS(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="BigInteger" maxLength="2"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).NAT_TITLE" usage="optional" id="NAT_TITLE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).NAT_TITLE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="350"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).SOURCE_AGENCY" usage="optional" id="SOURCE_AGENCY">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).SOURCE_AGENCY</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ORGANISATION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="6"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).SOURCE_PUB" usage="optional" id="SOURCE_PUB">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).SOURCE_PUB</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="350"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).TITLE" usage="optional" id="TITLE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TITLE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="200"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).TITLE_COMPL" usage="mandatory" id="TITLE_COMPL">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TITLE_COMPL</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat minLength="1" textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).UNIT" usage="mandatory" id="UNIT">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).UNIT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_UNIT(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="13"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_EXR1(1.0).UNIT_MULT" usage="mandatory" id="UNIT_MULT">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).UNIT_MULT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_UNIT_MULT(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="3"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>CURRENCY</str:Dimension>
                <str:Dimension>CURRENCY_DENOM</str:Dimension>
                <str:Dimension>EXR_TYPE</str:Dimension>
                <str:Dimension>EXR_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
          </str:AttributeList>
          <str:MeasureList urn="urn:sdmx:org.sdmx.infomodel.datastructure.MeasureDescriptor=SDMX:ECB_EXR1(1.0).MeasureDescriptor" id="MeasureDescriptor">
            <str:Measure urn="urn:sdmx:org.sdmx.infomodel.datastructure.Measure=SDMX:ECB_EXR1(1.0).OBS_VALUE" usage="optional" id="OBS_VALUE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_VALUE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat isSequence="false" textType="String" maxLength="30"/>
              </str:LocalRepresentation>
            </str:Measure>
          </str:MeasureList>
        </str:DataStructureComponents>
      </str:DataStructure>
      <str:DataStructure urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_TRD1(1.0)" isExternalReference="false" agencyID="SDMX" id="ECB_TRD1" uri="https://www.ecb.europa.eu/vocabulary/stats/trd/1" version="1.0">
        <com:Name xml:lang="en">External Trade</com:Name>
        <str:DataStructureComponents>
          <str:DimensionList urn="urn:sdmx:org.sdmx.infomodel.datastructure.DimensionDescriptor=SDMX:ECB_TRD1(1.0).DimensionDescriptor" id="DimensionDescriptor">
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).FREQ" id="FREQ" position="1">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).FREQ</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=SDMX:CL_FREQ(2.1)</str:Enumeration>
                <str:EnumerationFormat textType="String"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).REF_AREA" id="REF_AREA" position="2">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).REF_AREA</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_AREA_EE(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="2" textType="String" maxLength="4"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).ADJUSTMENT" id="ADJUSTMENT" position="3">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).ADJUSTMENT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ADJUSTMENT(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).TRD_FLOW" id="TRD_FLOW" position="4">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TRD_FLOW</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_TRD_FLOW(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).TRD_PRODUCT" id="TRD_PRODUCT" position="5">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TRD_PRODUCT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_TRD_PRODUCT(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="3" textType="String" maxLength="3"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).COUNT_AREA" id="COUNT_AREA" position="6">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COUNT_AREA</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_AREA_EE(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="2" textType="String" maxLength="4"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).STS_INSTITUTION" id="STS_INSTITUTION" position="7">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).STS_INSTITUTION</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_STS_INSTITUTION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:Dimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.Dimension=SDMX:ECB_TRD1(1.0).TRD_SUFFIX" id="TRD_SUFFIX" position="8">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TRD_SUFFIX</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_TRD_SUFFIX(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="3" textType="String" maxLength="3"/>
              </str:LocalRepresentation>
            </str:Dimension>
            <str:TimeDimension urn="urn:sdmx:org.sdmx.infomodel.datastructure.TimeDimension=SDMX:ECB_TRD1(1.0).TIME_PERIOD" id="TIME_PERIOD">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TIME_PERIOD</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="ObservationalTimePeriod"/>
              </str:LocalRepresentation>
            </str:TimeDimension>
          </str:DimensionList>
          <str:Group urn="urn:sdmx:org.sdmx.infomodel.datastructure.GroupDimensionDescriptor=SDMX:ECB_TRD1(1.0).Group" id="Group">
            <str:GroupDimension>
              <str:DimensionReference>REF_AREA</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>ADJUSTMENT</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>TRD_FLOW</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>TRD_PRODUCT</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>COUNT_AREA</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>STS_INSTITUTION</str:DimensionReference>
            </str:GroupDimension>
            <str:GroupDimension>
              <str:DimensionReference>TRD_SUFFIX</str:DimensionReference>
            </str:GroupDimension>
          </str:Group>
          <str:AttributeList urn="urn:sdmx:org.sdmx.infomodel.datastructure.AttributeDescriptor=SDMX:ECB_TRD1(1.0).AttributeDescriptor" id="AttributeDescriptor">
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).TIME_FORMAT" usage="mandatory" id="TIME_FORMAT">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TIME_FORMAT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="3"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).OBS_STATUS" usage="mandatory" id="OBS_STATUS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_STATUS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_OBS_STATUS(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).OBS_CONF" usage="optional" id="OBS_CONF">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_CONF</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_OBS_CONF(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).OBS_PRE_BREAK" usage="optional" id="OBS_PRE_BREAK">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_PRE_BREAK</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="30"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).OBS_COM" usage="optional" id="OBS_COM">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_COM</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Observation/>
              </str:AttributeRelationship>
              <str:MeasureRelationship>
                <str:Measure>OBS_VALUE</str:Measure>
              </str:MeasureRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).ADJU_DETAIL" usage="optional" id="ADJU_DETAIL">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).ADJU_DETAIL</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="350"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).BREAKS" usage="optional" id="BREAKS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).BREAKS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="350"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).COLLECTION" usage="mandatory" id="COLLECTION">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COLLECTION</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_COLLECTION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="1"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).COMPILING_ORG" usage="optional" id="COMPILING_ORG">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COMPILING_ORG</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ORGANISATION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="6"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).DISS_ORG" usage="optional" id="DISS_ORG">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).DISS_ORG</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ORGANISATION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="6"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).DOM_SER_IDS" usage="optional" id="DOM_SER_IDS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).DOM_SER_IDS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="70"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).PUBL_ECB" usage="optional" id="PUBL_ECB">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).PUBL_ECB</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).PUBL_MU" usage="optional" id="PUBL_MU">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).PUBL_MU</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).PUBL_PUBLIC" usage="optional" id="PUBL_PUBLIC">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).PUBL_PUBLIC</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).UNIT_INDEX_BASE" usage="optional" id="UNIT_INDEX_BASE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).UNIT_INDEX_BASE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="35"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>FREQ</str:Dimension>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).COMPILATION" usage="optional" id="COMPILATION">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).COMPILATION</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).DECIMALS" usage="mandatory" id="DECIMALS">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).DECIMALS</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_DECIMALS(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="BigInteger" maxLength="2"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).SOURCE_AGENCY" usage="optional" id="SOURCE_AGENCY">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).SOURCE_AGENCY</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_ORGANISATION(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="6"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).TITLE" usage="optional" id="TITLE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TITLE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="200"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).TITLE_COMPL" usage="mandatory" id="TITLE_COMPL">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).TITLE_COMPL</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat minLength="1" textType="String" maxLength="1050"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).UNIT" usage="mandatory" id="UNIT">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).UNIT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_UNIT(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="13"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
            <str:Attribute urn="urn:sdmx:org.sdmx.infomodel.datastructure.DataAttribute=SDMX:ECB_TRD1(1.0).UNIT_MULT" usage="mandatory" id="UNIT_MULT">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).UNIT_MULT</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:Enumeration>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_UNIT_MULT(1.0)</str:Enumeration>
                <str:EnumerationFormat minLength="1" textType="String" maxLength="3"/>
              </str:LocalRepresentation>
              <str:AttributeRelationship>
                <str:Dimension>REF_AREA</str:Dimension>
                <str:Dimension>ADJUSTMENT</str:Dimension>
                <str:Dimension>TRD_FLOW</str:Dimension>
                <str:Dimension>TRD_PRODUCT</str:Dimension>
                <str:Dimension>COUNT_AREA</str:Dimension>
                <str:Dimension>STS_INSTITUTION</str:Dimension>
                <str:Dimension>TRD_SUFFIX</str:Dimension>
              </str:AttributeRelationship>
            </str:Attribute>
          </str:AttributeList>
          <str:MeasureList urn="urn:sdmx:org.sdmx.infomodel.datastructure.MeasureDescriptor=SDMX:ECB_TRD1(1.0).MeasureDescriptor" id="MeasureDescriptor">
            <str:Measure urn="urn:sdmx:org.sdmx.infomodel.datastructure.Measure=SDMX:ECB_TRD1(1.0).OBS_VALUE" usage="optional" id="OBS_VALUE">
              <str:ConceptIdentity>urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=ECB:ECB_CONCEPTS(1.0).OBS_VALUE</str:ConceptIdentity>
              <str:LocalRepresentation>
                <str:TextFormat textType="String" maxLength="30"/>
              </str:LocalRepresentation>
            </str:Measure>
          </str:MeasureList>
        </str:DataStructureComponents>
      </str:DataStructure>
    </str:DataStructures>
    <str:RepresentationMaps>
      <str:RepresentationMap urn="urn:sdmx:org.sdmx.infomodel.structuremapping.RepresentationMap=SDMX:REPMAP_FREQ(1.0)" isExternalReference="false" agencyID="SDMX" id="REPMAP_FREQ" version="1.0">
        <com:Name xml:lang="en">RM_FREQ</com:Name>
        <str:SourceCodelist>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=ECB:CL_FREQ(1.0)</str:SourceCodelist>
        <str:TargetCodelist>urn:sdmx:org.sdmx.infomodel.codelist.Codelist=SDMX:CL_FREQ(2.1)</str:TargetCodelist>
        <str:RepresentationMapping>
          <str:SourceValue>A</str:SourceValue>
          <str:TargetValue>A</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>B</str:SourceValue>
          <str:TargetValue>B</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>D</str:SourceValue>
          <str:TargetValue>D</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>E</str:SourceValue>
          <str:TargetValue>I</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>H</str:SourceValue>
          <str:TargetValue>S</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>M</str:SourceValue>
          <str:TargetValue>M</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>N</str:SourceValue>
          <str:TargetValue>N</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>Q</str:SourceValue>
          <str:TargetValue>Q</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>S</str:SourceValue>
          <str:TargetValue>S</str:TargetValue>
        </str:RepresentationMapping>
        <str:RepresentationMapping>
          <str:SourceValue>W</str:SourceValue>
          <str:TargetValue>W</str:TargetValue>
        </str:RepresentationMapping>
      </str:RepresentationMap>
    </str:RepresentationMaps>
    <str:StructureMaps>
      <str:StructureMap urn="urn:sdmx:org.sdmx.infomodel.structuremapping.StructureMap=SDMX:MAP_EXR1(1.0)" isExternalReference="false" agencyID="SDMX" id="MAP_EXR1" version="1.0">
        <com:Name xml:lang="en">MAP_EXR1</com:Name>
        <str:Source>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=ECB:ECB_EXR1(1.0)</str:Source>
        <str:Target>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_EXR1(1.0)</str:Target>
        <str:ComponentMap>
          <str:Source>CURRENCY</str:Source>
          <str:Target>CURRENCY</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>CURRENCY_DENOM</str:Source>
          <str:Target>CURRENCY_DENOM</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>FREQ</str:Source>
          <str:Target>FREQ</str:Target>
          <str:RepresentationMap>urn:sdmx:org.sdmx.infomodel.structuremapping.RepresentationMap=SDMX:REPMAP_FREQ(1.0)</str:RepresentationMap>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>EXR_TYPE</str:Source>
          <str:Target>EXR_TYPE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>EXR_SUFFIX</str:Source>
          <str:Target>EXR_SUFFIX</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TIME_PERIOD</str:Source>
          <str:Target>TIME_PERIOD</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TIME_FORMAT</str:Source>
          <str:Target>TIME_FORMAT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_STATUS</str:Source>
          <str:Target>OBS_STATUS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_CONF</str:Source>
          <str:Target>OBS_CONF</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_PRE_BREAK</str:Source>
          <str:Target>OBS_PRE_BREAK</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_COM</str:Source>
          <str:Target>OBS_COM</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>BREAKS</str:Source>
          <str:Target>BREAKS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COLLECTION</str:Source>
          <str:Target>COLLECTION</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COMPILING_ORG</str:Source>
          <str:Target>COMPILING_ORG</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>DISS_ORG</str:Source>
          <str:Target>DISS_ORG</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>DOM_SER_IDS</str:Source>
          <str:Target>DOM_SER_IDS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>PUBL_ECB</str:Source>
          <str:Target>PUBL_ECB</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>PUBL_MU</str:Source>
          <str:Target>PUBL_MU</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>PUBL_PUBLIC</str:Source>
          <str:Target>PUBL_PUBLIC</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>UNIT_INDEX_BASE</str:Source>
          <str:Target>UNIT_INDEX_BASE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COMPILATION</str:Source>
          <str:Target>COMPILATION</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COVERAGE</str:Source>
          <str:Target>COVERAGE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>DECIMALS</str:Source>
          <str:Target>DECIMALS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>NAT_TITLE</str:Source>
          <str:Target>NAT_TITLE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>SOURCE_AGENCY</str:Source>
          <str:Target>SOURCE_AGENCY</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>SOURCE_PUB</str:Source>
          <str:Target>SOURCE_PUB</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TITLE</str:Source>
          <str:Target>TITLE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TITLE_COMPL</str:Source>
          <str:Target>TITLE_COMPL</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>UNIT</str:Source>
          <str:Target>UNIT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>UNIT_MULT</str:Source>
          <str:Target>UNIT_MULT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_VALUE</str:Source>
          <str:Target>OBS_VALUE</str:Target>
        </str:ComponentMap>
      </str:StructureMap>
      <str:StructureMap urn="urn:sdmx:org.sdmx.infomodel.structuremapping.StructureMap=SDMX:MAP_TDR1(1.0)" isExternalReference="false" agencyID="SDMX" id="MAP_TDR1" version="1.0">
        <com:Name xml:lang="en">MAP_TDR1</com:Name>
        <str:Source>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=ECB:ECB_TRD1(1.0)</str:Source>
        <str:Target>urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_TRD1(1.0)</str:Target>
        <str:ComponentMap>
          <str:Source>FREQ</str:Source>
          <str:Target>FREQ</str:Target>
          <str:RepresentationMap>urn:sdmx:org.sdmx.infomodel.structuremapping.RepresentationMap=SDMX:REPMAP_FREQ(1.0)</str:RepresentationMap>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>REF_AREA</str:Source>
          <str:Target>REF_AREA</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>ADJUSTMENT</str:Source>
          <str:Target>ADJUSTMENT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TRD_FLOW</str:Source>
          <str:Target>TRD_FLOW</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TRD_PRODUCT</str:Source>
          <str:Target>TRD_PRODUCT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COUNT_AREA</str:Source>
          <str:Target>COUNT_AREA</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>STS_INSTITUTION</str:Source>
          <str:Target>STS_INSTITUTION</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TRD_SUFFIX</str:Source>
          <str:Target>TRD_SUFFIX</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TIME_PERIOD</str:Source>
          <str:Target>TIME_PERIOD</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TIME_FORMAT</str:Source>
          <str:Target>TIME_FORMAT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_STATUS</str:Source>
          <str:Target>OBS_STATUS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_CONF</str:Source>
          <str:Target>OBS_CONF</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_PRE_BREAK</str:Source>
          <str:Target>OBS_PRE_BREAK</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_COM</str:Source>
          <str:Target>OBS_COM</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>ADJU_DETAIL</str:Source>
          <str:Target>ADJU_DETAIL</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>BREAKS</str:Source>
          <str:Target>BREAKS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COLLECTION</str:Source>
          <str:Target>COLLECTION</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COMPILING_ORG</str:Source>
          <str:Target>COMPILING_ORG</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>DISS_ORG</str:Source>
          <str:Target>DISS_ORG</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>DOM_SER_IDS</str:Source>
          <str:Target>DOM_SER_IDS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>PUBL_ECB</str:Source>
          <str:Target>PUBL_ECB</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>PUBL_MU</str:Source>
          <str:Target>PUBL_MU</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>PUBL_PUBLIC</str:Source>
          <str:Target>PUBL_PUBLIC</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>UNIT_INDEX_BASE</str:Source>
          <str:Target>UNIT_INDEX_BASE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>COMPILATION</str:Source>
          <str:Target>COMPILATION</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>DECIMALS</str:Source>
          <str:Target>DECIMALS</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>SOURCE_AGENCY</str:Source>
          <str:Target>SOURCE_AGENCY</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TITLE</str:Source>
          <str:Target>TITLE</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>TITLE_COMPL</str:Source>
          <str:Target>TITLE_COMPL</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>UNIT</str:Source>
          <str:Target>UNIT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>UNIT_MULT</str:Source>
          <str:Target>UNIT_MULT</str:Target>
        </str:ComponentMap>
        <str:ComponentMap>
          <str:Source>OBS_VALUE</str:Source>
          <str:Target>OBS_VALUE</str:Target>
        </str:ComponentMap>
      </str:StructureMap>
    </str:StructureMaps>
  </message:Structures>
</message:Structure>
EOF
)

SubmissionResult_to_table "$(echo "${additional_content}" | \
  curl -s -X POST \
    --user root:password \
    --header 'Content-Type: application/xml' \
    --header 'Action: Replace' \
    --data-binary @- \
     http://localhost:8080/ws/secure/sdmxapi/rest)"


token=$(curl -s -X POST \
  -F 'uploadFile=undefined' \
  -F 'dataUploadType=url' \
  -F "uploadUrl=https://data-api.ecb.europa.eu/service/data/ECB,EXR,1.0/...." \
  -F "dataFileName=...." \
  -F "dataFormat=auto" \
  -F "dsd=prov" \
  -F "csvDelimiter=comma" \
  'http://localhost:8080/ws/public/data/load' | jq -r '.uid')
if [ -z "$token" ]
then
    echo "Error with the request"
    exit 1
fi
while true
do
  response=$(curl -s -X GET  "http://localhost:8080/ws/public/data/loadStatus?uid=$token")
  status=$(echo "$response" | jq -r ".Status")
  echo "$token: $status"
  if [[ "$status" =~ ^(Complete|IncorrectDSD|InvalidRef|MissingDSD|Error)$ ]]
  then
    break
  fi
  sleep 5
done

curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"UID" : "'"$token"'", "SRef" : ["urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=SDMX:ECB_EXR1(1.0)", "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=SDMX:EXR(1.0)"] }' \
  'http://localhost:8080/ws/public/data/revalidate'
while true
do
  response=$(curl -s -X GET  "http://localhost:8080/ws/public/data/loadStatus?uid=$token")
  status=$(echo "$response" | jq -r ".Status")
  echo "$token: $status"
  if [[ "$status" =~ ^(Complete|IncorrectDSD|InvalidRef|MissingDSD|Error)$ ]]
  then
    break
  fi
  sleep 5
done
