<cfcomponent output="false">

	<!--- REMOTE PROXY 
	
	This acts as a safety handler to sit between your app and webservices you consume. If the webservice dies, your app doesn't have to. 
	To provide better availability, the data can be cached and made available offline. This proxy makes an effort to do that.
	
	1. It will only instantiate the webservices when data is first requested, allowing your app to wire up without requiring the service to be up.
	2. Webservices are stateless, and so, cannot cache their data. This proxy will retain state and therefore, retain queries.
	
	
	internals look like this:
	
	variables.methods[MethodName][ColumnList] 
	variables.methods[MethodName][XXXX-XXXX-XXXX] <-- hash of 1 set of arguments
	variables.methods[MethodName][YYYY-YYYY-YYYY] <-- hash of another set of args
	variables.methods[MethodName][ZZZZ-ZZZZ-ZZZZ] <-- hash of a third set, etc, so on, ie. hand-built caching
	--->
	
	<cfset variables.endpoint 		= "" />
	<cfset variables.credentials 	= StructNew() />
	<cfset variables.methods 		= StructNew() />

	<cffunction name="setEndpoint" returntype="void" access="public" output="false">
		<cfargument name="endpointURL" type="string" required="true" />
		
		<cfset variables.endpoint = arguments.endpointURL />
	</cffunction>
	
	<cffunction name="setCredentials" returntype="void" access="public" output="false">
		<cfargument name="username" type="string" required="true" />
		<cfargument name="password" type="string" required="true" />		
		
		<cfset variables.credentials.username = arguments.username />
		<cfset variables.credentials.password = arguments.password />
	</cffunction>	
	
    <cffunction name="onMissingMethod" returntype="any" access="public" output="false">
		<cfargument name="MissingMethodName" type="string" required="true" />
	    <cfargument name="MissingMethodArguments" type="struct" required="true" />
     
		<cfset var argValues = "" />
		<cfset var thisArg = 0 />
		<cfset var cacheKey = 0 />
		<cfset var data = 0 />
	    
	    <!--- loop over the arguments, create a hash --->
	    <cfloop list="#StructKeyList(arguments.missingMethodArguments)#" index="thisArg">
	    	<cfset argValues = ListAppend( argValues, arguments.missingMethodArguments[thisArg] ) />
		</cfloop>
		
		<cfset cacheKey = Hash( argValues ) />
		
		<!--- does it exist in the cache? --->
		<cfif NOT StructKeyExists( variables.methods, arguments.missingMethodName )>
			<cfset variables.methods[arguments.missingMethodName] = StructNew() />
		</cfif>
		
		<cfif NOT StructKeyExists( variables.methods[arguments.missingMethodName], cacheKey )>

			<!--- it does not exist, so make the webservice call and cache the results --->
			<cftry>
			
				<cfif StructIsEmpty(variables.credentials)>
		
					<cfinvoke webservice="#variables.endpoint#"
						method="#arguments.missingMethodName#"
						returnVariable="data"
						argumentCollection="#arguments.missingMethodArguments#"
						timeout="45" />
		
				<cfelse>
		
					<cfinvoke webservice="#variables.endpoint#"
						method="#arguments.missingMethodName#"
						returnVariable="data"
						argumentCollection="#arguments.missingMethodArguments#"
						timeout="45"
						username="#variables.credentials.username#"
						password="#variables.credentials.password#" />			
		
				</cfif>

				<cfset variables.methods[arguments.missingMethodName][cacheKey] = data />
				
				<!--- is the column list registered? Register it if not, for when the services dies later. --->
				<cfif IsQuery( data ) AND NOT StructKeyExists( variables.methods[arguments.missingMethodName], 'ColumnList' )>
					
					<cfset variables.methods[arguments.missingMethodName]['ColumnList'] = data.ColumnList />

				</cfif>
			
				<cfcatch type="any">

					<!--- ok, we failed, presumably due to at timeout, so log the actual error --->
					<cflog file="RemoteProxy" text="#CFCATCH.Message# - #CFCATCH.Detail#" />
					
					<!--- you may want to do additional things here, like freak out and email admins and such --->

					<!--- let's not have our website die completely with hard errors. Send an empty query back, based on the columns of the actual query, when it was alive --->
					<cfif StructKeyExists( variables.methods[arguments.missingMethodName], 'ColumnList' )>

						<cfset variables.methods[arguments.missingMethodName][cacheKey] = QueryNew( variables.methods[arguments.missingMethodName].ColumnList ) />

					<cfelse>

						<!--- if you get this far, its because your web service never completed a single call to the method in question. But, take comfort in knowing
						you did a hell of a lot more to protect against it than just a single cfinvoke, assuming all would be well. --->

						<cfrethrow />

					</cfif>

				</cfcatch>

			</cftry>

		</cfif>
	    
	    <cfreturn variables.methods[arguments.missingMethodName][cacheKey] />
    </cffunction>	

</cfcomponent>