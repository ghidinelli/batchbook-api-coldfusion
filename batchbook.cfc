<cfcomponent displayname="Batchbook V2 REST API Client" output="false">
	
	<cfset variables.instance = StructNew() />

	<cfset variables.instance.api_key = '' />
	<cfset variables.instance.root_uri = '' />
	
	<!--- helper class to deal with dates in BB format --->
	<cfset variables.instance.dateformatter = createObject("java", "java.text.SimpleDateFormat") />
	<cfset variables.instance.dateformatter.init("yyyy-MM-dd'T'HH:mm:ss") />

	
	<cffunction name="init" output="false" access="public" returntype="any">
		<cfargument name="Endpoint" type="string" required="true" />
		<cfargument name="APIKey" type="string" required="true" />
		<cfargument name="RestConsumer" type="any" required="true" />

		<cfset variables.instance.api_key = arguments.apikey />
		<cfset variables.instance.root_uri = arguments.endpoint />
		<cfset variables.RestConsumer = arguments.RestConsumer />
		
		<cfset variables.RestConsumer.setDebug(false) />
		<cfset variables.RestConsumer.setRateLimit(1) />

		<cfreturn this />		
	</cffunction>


	<cffunction name="getCustomFields" access="public" returntype="any" output="false">
		<cfreturn doRemoteCall(method = "GET", resource = "/custom_field_sets.json", payload = structNew()) />
	</cffunction>


	<!--- make it possible to follow a redirect to get the updated representation --->
	<cffunction name="follow" output="false" access="public" returntype="any">
		<cfargument name="uri" type="any" required="true" />
	
		<!--- clean the base off and make it into a resource --->
		<cfset var resource = replaceNoCase(arguments.uri, variables.instance.root_uri, "") & ".json" />
	
		<cfreturn doRemoteCall(method = "GET", resource = resource, payload = structNew()) />
	</cffunction>


	<cffunction name="findCompany" output="false" access="public" returntype="any" hint="Search on email, tags, name, updated_since, updated_before and state.  Optionally pass in page=X to specify which page of results.">
		<!--- case-sensitive page argument name: cfargument name="page" type="numeric" required="false" default="1" / --->
		
		<cfreturn doRemoteCall(method = "GET", resource = "/companies.json", payload = arguments) />
	</cffunction>


	<cffunction name="getCompany" access="public" returntype="any" output="false">
		<cfargument name="id" type="numeric" required="true" />

		<cfreturn doRemoteCall(method = "GET", resource = "/companies/#arguments.id#.json", payload = structNew()) />
	</cffunction>


	<cffunction name="saveCompany" access="public" returntype="any" output="false">
		<cfargument name="company" type="struct" required="true" />

		<!--- if the person has an ID, they must already exist, so we PUT an update; otherwise we POST to create --->
		<cfif structKeyExists(company, "company") AND structKeyExists(company.company, "id") AND isNumeric(company.company.id)>
			<!--- response is 200 OK --->
			<cfreturn doRemoteCall(method = "PUT", resource = "/companies/#company.company.id#.json", payload = serializeJson(arguments.company)) />
		<cfelse>
			<!--- response looks like: 
				Status: 201 Created
				Location: https://your_account.batchbook.com/api/v1/companies/the_new_id.{json or xml}		
			--->
			<cfreturn doRemoteCall(method = "POST", resource = "/companies.json", payload = serializeJson(arguments.company)) />
		</cfif>

	</cffunction>


	<cffunction name="findPeople" output="false" access="public" returntype="any" hint="Search on email, tags, name, updated_since, updated_before, state, champion, company_name, company_id.  Optionally pass in page=X to specify which page of results in increments of 30.">
		<!--- case-sensitive page argument name: cfargument name="page" type="numeric" required="false" default="1" / --->
		
		<cfreturn doRemoteCall(method = "GET", resource = "/people.json", payload = arguments) />
	</cffunction>


	<cffunction name="getPeople" access="public" returntype="any" output="false">
		<cfargument name="id" type="numeric" required="true" />

		<cfreturn doRemoteCall(method = "GET", resource = "/people/#arguments.id#.json", payload = structNew()) />
	</cffunction>
	
	
	<cffunction name="savePeople" access="public" returntype="any" output="false">
		<cfargument name="people" type="struct" required="true" />

		<!--- if the person has an ID, they must already exist, so we PUT an update; otherwise we POST to create --->
		<cfif structKeyExists(people, "person") AND structKeyExists(people.person, "id") AND isNumeric(people.person.id)>
			<!--- response is 200 OK --->
			<cfreturn doRemoteCall(method = "PUT", resource = "/people/#people.person.id#.json", payload = serializeJson(arguments.people)) />
		<cfelse>
			<!--- response looks like: 
				Status: 201 Created
				Location: https://your_account.batchbook.com/api/v1/people/the_new_id.{json or xml}		
			--->
			<cfreturn doRemoteCall(method = "POST", resource = "/people.json", payload = serializeJson(arguments.people)) />
		</cfif>
	</cffunction>





	<!--- PRIVATE METHODS --->

	<cffunction name="doRemoteCall" output="false" access="private" returntype="any">
		<cfargument name="method" type="any" required="true" default="GET" />
		<cfargument name="resource" type="any" required="true" />
		<cfargument name="headers" type="any" required="false" default="#structNew()#" />
		<cfargument name="payload" type="any" required="false" default="#structNew()#" />
	
		<cfset var uri = variables.instance.root_uri & arguments.resource />
		<cfset var res = "" />

		<!--- append the authkey to the URL either directly or to the payload for GET requests --->
		<cfif uCase(arguments.method) EQ "GET" AND isStruct(arguments.payload)>
			<cfset structInsert(arguments.payload, "auth_token", getAuthKey(), true) />
		<cfelse>
			<cfset uri &= "?auth_token=#getAuthKey()#" />
		</cfif>

		<!--- all requests require a content-type: application/json header --->
		<cfset structInsert(arguments.headers, "Content-Type", "application/json; charset=utf-8", false) />

		<cfif isJSON(arguments.payload)>
			<!--- because serializeJson in CF 8 likes to change numbers from strings to floats, we have to hack postal addresses which may be undesirably changed: http://www.ghidinelli.com/2008/12/19/tricking-serializejson-to-treat-numbers-as-strings --->
			<!--- deserialize/serialize also likes to drop the quotes around the postal code; sigh: --->
			<cfset arguments.payload = reReplace(arguments.payload, '"postal_code":(" )?([-0-9]{5,10})(.0)?(")?', '"postal_code":"\2"', "ALL") />
			<!--- serializejson also likes to convert 33 to 33.0 which breaks all ID numbers --->
			<cfset arguments.payload = reReplace(arguments.payload, 'id":([0-9]+)\.0', 'id":\1', "ALL") />
		</cfif>
		
		<cfset res = variables.restconsumer.process(url = uri, method = arguments.method, payload = arguments.payload, headers = arguments.headers, timeout = 30) />
		
		<cfif res.complete AND (NOT len(trim(res.content)) OR isJSON(res.content))>
			<cfreturn res />
		<cfelse>
			<cfdump var="#res#" output="console" />
			<cfthrow message="Error" detail="The response from #arguments.resource# was not JSON" extendedinfo="#res.content#" />
		</cfif>
		
	</cffunction>


	<!--- returns a case sensitive structure for serializtion --->
	<cffunction name="node" output="false" access="public" returntype="struct">
		<!--- because serializeJson in CF 8 likes to change numbers from strings to floats, we have to hack postal addresses which may be undesirably changed: http://www.ghidinelli.com/2008/12/19/tricking-serializejson-to-treat-numbers-as-strings --->
		<cfif structKeyExists(arguments, "postal_code")>
			<!--- prepend a space which forces it to be treated as a string by serializejson - it will be stripped out in doRemoteCall --->
			<cfset arguments["postal_code"] = " #arguments["postal_code"]#" />
		</cfif>
		<cfreturn arguments />
	</cffunction>


	<cffunction name="formatDate" output="false" access="public" returntype="string" hint="Takes ColdFusion date/time object and converts to a string like 2011-04-25T03:00:00-07:00">
		<!--- dates are all formatted like 2011-04-25T03:00:00-07:00 --->
		<cfif isDate(arguments[1])>
			<cfreturn dateFormat(arguments[1], "yyyy-mm-dd") & "T" & timeFormat(arguments[1], "HH:mm:ss") & "-08:00" />
		<cfelse>
			<cfreturn dateFormat(parseDateTime(arguments[1]), "yyyy-mm-dd") & "T" & timeFormat(parseDateTime(arguments[1]), "HH:mm:ss") & "-08:00" />
		</cfif>
	</cffunction>


	<cffunction name="parseDate" output="false" access="public" returntype="any" hint="Takes string like 2011-04-25T03:00:00-07:00 and returns a ColdFusion date/time object">
		<cfset var parsePosition = CreateObject("java", "java.text.ParsePosition") />
		<cfset parsePosition.init(0) />
		<cfreturn variables.instance.dateformatter.parse(arguments[1], parsePosition) />
	</cffunction>


	<cffunction name="findFieldSetInArray" output="false" access="public" returntype="any">
		<cfargument name="array" type="any" required="true" />
		<cfargument name="custom_field_set_id" type="numeric" required="true" />
	
		<cfset var len = arrayLen(arguments.array) />
		<cfset var ii = "" />
		
		<cfloop from="1" to="#len#" index="ii">
			<cfif array[ii]["custom_field_set_id"] EQ arguments.custom_field_set_id>
				<cfreturn array[ii] />
			</cfif>
		</cfloop>

		<cfreturn structNew() />
	</cffunction>


	<cffunction name="findValueInFieldSet" output="false" access="public" returntype="any">
		<cfargument name="fieldset" type="any" required="true" />
		<cfargument name="custom_field_definition_id" type="numeric" required="true" />
	
		<cfset var len = arrayLen(arguments.fieldset.custom_field_values) />
		<cfset var ii = "" />
		
		<cfloop from="1" to="#len#" index="ii">
			<cfif fieldset["custom_field_values"][ii]["custom_field_definition_id"] EQ arguments.custom_field_definition_id>
				<cfreturn fieldset["custom_field_values"][ii] />
			</cfif>
		</cfloop>

		<cfreturn structNew() />
	</cffunction>
	

	<!--- Accessor methods --->
	<cffunction name="getAuthKey" output="false" access="private" returntype="any">
		<cfreturn variables.instance.api_key />
	</cffunction>
	

</cfcomponent>