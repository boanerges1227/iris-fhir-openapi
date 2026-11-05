Class FHIR.OpenAPI.Capability.Parser Extends %RegisteredObject
{
/// Fixed R4 resource names; reject malicious paths and resources exclusive to other versions.
ClassMethod ResourceNames() As %String
{
    Quit "|Account|ActivityDefinition|AdverseEvent|AllergyIntolerance|Appointment|AppointmentResponse|AuditEvent|Basic|Binary|BiologicallyDerivedProduct|BodyStructure|Bundle|CapabilityStatement|CarePlan|CareTeam|CatalogEntry|ChargeItem|ChargeItemDefinition|Claim|ClaimResponse|ClinicalImpression|CodeSystem|Communication|CommunicationRequest|CompartmentDefinition|Composition|ConceptMap|Condition|Consent|Contract|Coverage|CoverageEligibilityRequest|CoverageEligibilityResponse|DetectedIssue|Device|DeviceDefinition|DeviceMetric|DeviceRequest|DeviceUseStatement|DiagnosticReport|DocumentManifest|DocumentReference|EffectEvidenceSynthesis|Encounter|Endpoint|EnrollmentRequest|EnrollmentResponse|EpisodeOfCare|EventDefinition|Evidence|EvidenceVariable|ExampleScenario|ExplanationOfBenefit|FamilyMemberHistory|Flag|Goal|GraphDefinition|Group|GuidanceResponse|HealthcareService|ImagingStudy|Immunization|ImmunizationEvaluation|ImmunizationRecommendation|ImplementationGuide|InsurancePlan|Invoice|Library|Linkage|List|Location|Measure|MeasureReport|Media|Medication|MedicationAdministration|MedicationDispense|MedicationKnowledge|MedicationRequest|MedicationStatement|MedicinalProduct|MedicinalProductAuthorization|MedicinalProductContraindication|MedicinalProductIndication|MedicinalProductIngredient|MedicinalProductInteraction|MedicinalProductManufactured|MedicinalProductPackaged|MedicinalProductPharmaceutical|MedicinalProductUndesirableEffect|MessageDefinition|MessageHeader|MolecularSequence|NamingSystem|NutritionOrder|Observation|ObservationDefinition|OperationDefinition|OperationOutcome|Organization|OrganizationAffiliation|Parameters|Patient|PaymentNotice|PaymentReconciliation|Person|PlanDefinition|Practitioner|PractitionerRole|Procedure|Provenance|Questionnaire|QuestionnaireResponse|RelatedPerson|RequestGroup|ResearchDefinition|ResearchElementDefinition|ResearchStudy|ResearchSubject|RiskAssessment|RiskEvidenceSynthesis|Schedule|SearchParameter|ServiceRequest|Slot|Specimen|SpecimenDefinition|StructureDefinition|StructureMap|Subscription|Substance|SubstanceNucleicAcid|SubstancePolymer|SubstanceProtein|SubstanceReferenceInformation|SubstanceSourceMaterial|SubstanceSpecification|SupplyDelivery|SupplyRequest|Task|TerminologyCapabilities|TestReport|TestScript|ValueSet|VerificationResult|VisionPrescription|"
}
/// Validate and merge server-side capabilities; all unsafe deductions become diagnostics instead of guesses.
ClassMethod Parse(cap As %DynamicObject, report As %DynamicObject) As %DynamicObject
{
    Do ##class(FHIR.OpenAPI.Deadline).Check()
    Set model={"resources":{},"interactions":{},"searchParams":{},"operations":[],"formats":[],"patchFormats":[],"fhirVersion":"4.0.1"}
    If '$IsObject(cap) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Input must be a JSON object.") Quit model
    If '..Shape(cap,report) Quit model
    If cap.%Get("resourceType")'="CapabilityStatement" Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Only CapabilityStatement is supported.","/resourceType") Quit model
    If cap.%Get("fhirVersion")'="4.0.1" Do ##class(FHIR.OpenAPI.Report).Add(report,"FHIR_VERSION_UNSUPPORTED","error","Initial release supports FHIR R4 4.0.1 only.","/fhirVersion")
    If $IsObject(cap.%Get("imports")),cap.imports.%Size() Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_IMPORTS_UNRESOLVED","error","Please supply a self-contained snapshot with actually resolved inherited capabilities.","/imports")
    Do ..CheckModifiers(cap,report,"")
    If cap.%Get("kind")="requirements" Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_REQUIREMENTS","error","Requirements declarations cannot be exported as actual services.","/kind")
    If cap.%Get("kind")="capability" Do ##class(FHIR.OpenAPI.Report).Add(report,"SOFTWARE_CAPABILITY","warning","Software capability statements do not guarantee that all features are enabled in the current deployment.","/kind")
    Set meta=cap.%Get("meta"),tags=$Select($IsObject(meta):meta.%Get("tag"),1:"")
    If '$IsObject(tags) Set tags=[]
    For i=0:1:tags.%Size()-1 {
        If tags.%Get(i).%Get("code")="SUBSETTED" Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_SUBSETTED","error","Incomplete summary snapshots are rejected.","/meta/tag")
    }
    Set formats=cap.%Get("format"),hasJSON=0
    If '$IsObject(formats) Set formats=[]
    For i=0:1:formats.%Size()-1 {
        Set fmt=formats.%Get(i)
        If (fmt="json")!(fmt="application/fhir+json")!(fmt="application/json") Set hasJSON=1
    }
    If 'hasJSON Do ##class(FHIR.OpenAPI.Report).Add(report,"JSON_FORMAT_UNDECLARED","error","Source does not declare JSON format.","/format")
    Set model.formats=$Select($IsObject(formats):formats,1:[])
    If $IsObject(cap.%Get("patchFormat")) Set model.patchFormats=cap.patchFormat
    Set rests=cap.%Get("rest"),serverCount=0
    If '$IsObject(rests) Set rests=[]
    For i=0:1:rests.%Size()-1 {
        Set rest=rests.%Get(i),ptr="/rest/"_i
        If rest.%Get("mode")'="server" Continue
        Set serverCount=serverCount+1
        Do ..Interactions(rest.%Get("interaction"),model.interactions,report,ptr_"/interaction",1)
        Do ..Search(rest.%Get("searchParam"),model.searchParams,report,ptr_"/searchParam")
        Do ..Operations(rest.%Get("operation"),model.operations,report,ptr_"/operation","")
        Set resources=rest.%Get("resource")
        If '$IsObject(resources) Continue
        For j=0:1:resources.%Size()-1 {
            Set raw=resources.%Get(j),name=raw.%Get("type"),rptr=ptr_"/resource/"_j
            If '##class(FHIR.OpenAPI.Options).Member(..ResourceNames(),name) Do ##class(FHIR.OpenAPI.Report).Add(report,"RESOURCE_UNKNOWN","error","Resource name is not part of R4.",rptr_"/type") Continue
            If model.resources.%IsDefined(name) {
                Set target=model.resources.%Get(name)
            } Else {
                Set target={"type":(name),"interactions":{},"searchParams":{},"flags":{},"profiles":[]}
                Do model.resources.%Set(name,target)
            }
            Do ..Interactions(raw.%Get("interaction"),target.interactions,report,rptr_"/interaction",0)
            Do ..Search(raw.%Get("searchParam"),target.searchParams,report,rptr_"/searchParam")
            Do ..Operations(raw.%Get("operation"),model.operations,report,rptr_"/operation",name)
            For flag="updateCreate","conditionalCreate","conditionalRead","conditionalUpdate","conditionalDelete","versioning","readHistory" {
                If 'raw.%IsDefined(flag) Continue
                Set allowed=$Select(flag="conditionalRead":"|not-supported|modified-since|not-match|full-support|",flag="conditionalDelete":"|not-supported|single|multiple|",flag="versioning":"|no-version|versioned|versioned-update|",1:"")
                If allowed="",raw.%GetTypeOf(flag)'="boolean" Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Conditional flag must be a JSON boolean.",rptr_"/"_flag) Continue
                If allowed'="",'##class(FHIR.OpenAPI.Options).Member(allowed,raw.%Get(flag)) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Invalid conditional capability enumeration.",rptr_"/"_flag) Continue
                If target.flags.%IsDefined(flag),(target.flags.%Get(flag)'=raw.%Get(flag)) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_CONFLICT","error","Conflicting conditional flags on the same resource.",rptr_"/"_flag,name) Continue
                Do target.flags.%Set(flag,raw.%Get(flag),raw.%GetTypeOf(flag))
            }
            If raw.%IsDefined("profile") {
                If raw.%GetTypeOf("profile")'="string" { Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Profile must be a canonical string.",rptr_"/profile") } Else { Do target.profiles.%Push(raw.profile) }
            }
            Set profiles=raw.%Get("supportedProfile")
            If $IsObject(profiles) For k=0:1:profiles.%Size()-1 Do target.profiles.%Push(profiles.%Get(k))
        }
    }
    If 'serverCount Do ##class(FHIR.OpenAPI.Report).Add(report,"SERVER_CAPABILITY_MISSING","error","No server-side REST capability.","/rest")
    Set report.counts.declaredResources=model.resources.%Size()
    Quit model
}
/// Recursively reject unknown modifierExtension; it may alter the interpretation of any nested element.
ClassMethod CheckModifiers(value, report, pointer As %String)
{
    If '$IsObject(value) Quit
    Set iter=value.%GetIterator()
    While iter.%GetNext(.key,.item) {
        If key="modifierExtension" {
            Do ..Array(item,report,pointer_"/modifierExtension","object")
        }
        If key="extension" {
            Do ..Array(item,report,pointer_"/extension","object")
            Do ##class(FHIR.OpenAPI.Report).Add(report,"EXTENSION_NOT_INTERPRETED","warning","Ordinary extensions are not used in generation; please manually review their meaning.",pointer_"/extension")
        }
        If key="modifierExtension",$IsObject(item),item.%Size() Do ##class(FHIR.OpenAPI.Report).Add(report,"UNKNOWN_MODIFIER_EXTENSION","error","Initial release does not interpret modifierExtension.",pointer_"/modifierExtension")
        If $IsObject(item) Do ..CheckModifiers(item,report,pointer_"/"_key)
    }
}
/// Deduplicate declared standard interactions; validate that system-level and resource-level interaction codes cannot mix.
ClassMethod Interactions(items, target, report, pointer, system As %Boolean)
{
    If '$IsObject(items) Quit
    Set allowed=$Select(system:"|transaction|batch|search-system|history-system|",1:"|read|vread|update|patch|delete|history-instance|history-type|create|search-type|")
    For i=0:1:items.%Size()-1 {
        Set code=items.%Get(i).%Get("code")
        If '##class(FHIR.OpenAPI.Options).Member(allowed,code) Do ##class(FHIR.OpenAPI.Report).Add(report,"INTERACTION_UNKNOWN","error","Invalid R4 interaction code.",pointer_"/"_i) Continue
        Do target.%Set(code,1,"boolean")
    }
}
/// Merge search parameters by name; reject overwrites when type or definition conflicts.
ClassMethod Search(items, target, report, pointer)
{
    If '$IsObject(items) Quit
    For i=0:1:items.%Size()-1 {
        Set raw=items.%Get(i),name=raw.%Get("name"),type=raw.%Get("type")
        For field="name","type","definition","documentation" {
            If raw.%IsDefined(field),raw.%GetTypeOf(field)'="string" Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Search parameter fields must be strings.",pointer_"/"_i_"/"_field)
        }
        If (name="")!('##class(FHIR.OpenAPI.Options).Member("|number|date|string|token|reference|composite|quantity|uri|special|",type)) Do ##class(FHIR.OpenAPI.Report).Add(report,"SEARCH_PARAMETER_INVALID","error","Search parameter must have a valid name and type.",pointer_"/"_i) Continue
        If target.%IsDefined(name) {
            Set prior=target.%Get(name)
            If (prior.type'=type)!(prior.%Get("definition")'=raw.%Get("definition")) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_CONFLICT","error","Conflicting definitions for a search parameter with the same name.",pointer_"/"_i)
        } Else { Do target.%Set(name,##class(FHIR.OpenAPI.JSON).Copy(raw)) }
    }
}
/// Custom operations are not currently guessed for HTTP location and method; uncovered reasons are fully recorded.
ClassMethod Operations(items, target, report, pointer, resource)
{
    If '$IsObject(items) Quit
    For i=0:1:items.%Size()-1 {
        Set omitted={"resource":(resource),"definition":(items.%Get(i).%Get("definition")),"name":(items.%Get(i).%Get("name")),"sourcePointer":(pointer_"/"_i)}
        Do target.%Push(omitted),report.omittedOperations.%Push(omitted)
        Do ##class(FHIR.OpenAPI.Report).Add(report,"CUSTOM_OPERATION_SKIPPED","warning","Initial release does not resolve OperationDefinition; this operation is omitted.",pointer_"/"_i,resource)
    }
}
/// Check all containers to be visited before iteration; malformed input is classified as 422 instead of a runtime 500.
ClassMethod Shape(cap, report) As %Boolean
{
    If cap.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Capability top-level must be an object.") Quit 0
    If '##class(FHIR.OpenAPI.Options).Member("|instance|capability|requirements|",cap.%Get("kind")) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Invalid kind enumeration.","/kind")
    If cap.%IsDefined("meta") {
        Set meta=cap.meta
        If '$IsObject(meta) { Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","meta must be an object.","/meta") } Else {
            If meta.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","meta cannot be an array.","/meta")
            If meta.%IsDefined("tag") Do ..Array(meta.%Get("tag"),report,"/meta/tag","object")
        }
    }
    For field="rest","imports","format","patchFormat" {
        If cap.%IsDefined(field) Do ..Array(cap.%Get(field),report,"/"_field,$Select(field="rest":"object",1:"string"))
    }
    If ##class(FHIR.OpenAPI.Report).HasErrors(report) Quit 0
    Set rests=cap.%Get("rest")
    If '$IsObject(rests) Quit 1
    For i=0:1:rests.%Size()-1 {
        Set rest=rests.%Get(i),ptr="/rest/"_i
        If '##class(FHIR.OpenAPI.Options).Member("|server|client|",rest.%Get("mode")) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Invalid REST mode enumeration.",ptr_"/mode")
        For field="resource","interaction","searchParam","operation" {
            If rest.%IsDefined(field) Do ..Array(rest.%Get(field),report,ptr_"/"_field,"object")
        }
        If ##class(FHIR.OpenAPI.Report).HasErrors(report) Quit
        Set resources=rest.%Get("resource")
        If '$IsObject(resources) Continue
        For j=0:1:resources.%Size()-1 {
            Set raw=resources.%Get(j),rptr=ptr_"/resource/"_j
            For field="interaction","searchParam","operation","supportedProfile" {
                If raw.%IsDefined(field) Do ..Array(raw.%Get(field),report,rptr_"/"_field,$Select(field="supportedProfile":"string",1:"object"))
            }
        }
    }
    Quit '##class(FHIR.OpenAPI.Report).HasErrors(report)
}
/// Constrain array element types to prevent scalars from being treated as objects when calling methods.
ClassMethod Array(value, report, pointer, kind)
{
    If '$IsObject(value) Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","This field requires an array.",pointer) Quit
    If 'value.%IsA("%DynamicArray") Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","This field requires an array.",pointer) Quit
    For i=0:1:value.%Size()-1 {
        Set item=value.%Get(i),valid=1
        If kind="object" Set valid=$IsObject(item)
        If kind="object",valid Set valid='item.%IsA("%DynamicArray")
        If kind="string" Set valid=(value.%GetTypeOf(i)="string")
        If 'valid Do ##class(FHIR.OpenAPI.Report).Add(report,"CAPABILITY_INVALID","error","Invalid array element type.",pointer_"/"_i)
    }
}
}
