batchbook-api-coldfusion
========================

ColdFusion client for Batchbook v2 API at https://github.com/batchblue/batchbook-api


Usage
========================
I wrote a helper library for interfacing with REST APIs from ColdFusion.  It's required and you can download it here:
https://github.com/ghidinelli/restconsumer

Initialize the client:

restconsumer = createObject("component", "restconsumer");
batchbook = createObject("component", "batchbook").init(RestConsumer = restconsumer, APIKey = 'Your-Key', Endpoint = 'https://yourHost.batchbook.com/api/v1');

Make some calls:

<cfset res = batchbook.findCompany(name = 'Some Company Name') />

Check to see if it succeeds and has content:

<cfif res.complete AND res.status EQ 200 AND isJSON(res.content)>
	<cfdump var="#deserializeJSON(res.content)#" />
</cfif>

If you have a contact ID, get the person or company record:

<cfset res = batchbook.getCompany(167) />
<cfset res = batchbook.getPeople(122) />



Create People (note, for CF8 compatibility which does not maintain case sensitivity in in-line structs/arrays, we use an argumentCollection hack represented as node()).  One CF9+ I think you can just use inline syntax so long as case-sensitivity is maintained (which is required by the BB API):

<cfset req = {} />
<cfset req["person"] = batchbook.node(about = "All around cool guy.", first_name = "Eric", middle_name = "M", last_name = "Krause") />
<cfset req.person["emails"] = [batchbook.node(address = "bar@example.com", label = "work")] />
<cfset req.person["phones"] = [batchbook.node(number = "401.867.5309", label = "cell")] />
<cfset req.person["websites"] = [batchbook.node(address = "http://www.batchblue.com", label = "work")] />
<cfset req.person["addresses"] = [batchbook.node(address_1 = "171 Chestnut Street", address_2 = "2L", city = "Providence", state = "RI", postal_code = "02903", country = "United States", label = "work")] />
<cfset req.person["company_affiliations"] = [batchbook.node(company_id = 1355, current = true, job_title = "")] />
<cfset res = batchbook.savePeople(req) />

savePeople() can also update records; it will look for the presence of an ID to determine if it is creating or updating.

Creating a record returns a Location header in the result struct with the URI to the new resource.  You can easily fetch it like this:

<cfset res = batchbook.follow(res.headers["Location"]) />

Companies are created and updated the same way.  This one includes a custom field set:

<cfset req = structNew() />
<cfset req["company"] = batchbook.node(name = "Batchbook Test", about = "A great company to work for") />
<cfset req.company["emails"] = [batchbook.node(address = "test@test.com", label = "work")] />
<cfset req.company["phones"] = [batchbook.node(number = "415.555.1212", label = "work")] />
<cfset req.company["websites"] = [batchbook.node(address = "http://www.test.com", label = "work")] />
<cfset req.company["addresses"] = [batchbook.node(address_1 = "123 Anywhere Lane", address_2 = "Unit 253", city = "San Rafael", state = "California", postal_code = "94903", country = "United States", label = "work")] />
<cfset nested = [batchbook.node(custom_field_definition_id = 38, serialized_value = listToArray("New"))
				,batchbook.node(custom_field_definition_id = 11, serialized_value = listToArray("Standard Plan - No Fees Whatsoever"))
				,batchbook.node(custom_field_definition_id = 12, text_value = "foo.com")
				,batchbook.node(custom_field_definition_id = 13, boolean_value = false)
				,batchbook.node(custom_field_definition_id = 14, datetime_value = batchbook.formatDate(now()))
				,batchbook.node(custom_field_definition_id = 15, text_value = "Form comments from sales lead")
				] />
<cfset req.company["cf_records"] = [batchbook.node(custom_field_set_id = 3, custom_field_values = nested)] />
<cfset res = batchbook.saveCompany(req) />

(again, in CF9 and above which has better inline array/struct creation, the use of node() is not required.


Get all of your custom field set definitions:

<cfset res = batchbook.getCustomFields() />
