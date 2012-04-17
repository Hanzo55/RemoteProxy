<cfcomponent output="false">

	<!--- REMOTE PROXY 
	
	This acts as a safety handler to sit between your app and webservices you consume. If the webservice dies, your app doesn't have to. 
	To provide better availability, the data can be cached and made available offline. This proxy makes an effort to do that.
	
	1. It will only instantiate the webservices when data is first requested, allowing your app to wire up without requiring the service to be up.
	2. Webservices are stateless, and so, cannot cache their data. This proxy will retain state and therefore, retain queries.
	
	
	internals look like this:
	
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
		<cfset var firstKey = "" />
		<cfset var data = 0 />
		<cfset var defaultSet = 0 />
	    
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
			
				<cfif StructIsEmpty( variables.credentials )>
		
					<cfinvoke webservice="#variables.endpoint#"
							method="#arguments.missingMethodName#"
							returnVariable="data"
							argumentCollection="#arguments.missingMethodArguments#"
							timeout="10" />
		
				<cfelse>
		
					<cfinvoke webservice="#variables.endpoint#"
							method="#arguments.missingMethodName#"
							returnVariable="data"
							argumentCollection="#arguments.missingMethodArguments#"
							timeout="10"
							username="#variables.credentials.username#"
							password="#variables.credentials.password#" />			
		
				</cfif>

				<cfset variables.methods[arguments.missingMethodName][cacheKey] = data />
				
				<cfcatch type="any">

					<!--- ok, we failed, presumably due to at timeout, so log the actual error --->
					<cflog file="RemoteProxy" text="#CFCATCH.Message# - #CFCATCH.Detail#" />
					
					<!--- do we have *anything* in the cache we can use as a map? --->					
					<cfif NOT StructIsEmpty( variables.methods[arguments.missingMethodName] )>
						
						<cfset firstKey = ListFirst( StructKeyList( variables.methods[arguments.missingMethodName] ) ) />
						
						<cfset defaultSet = CreateObject( 'component', 'DefaultTypeDelegate' ) />
						<cfset defaultSet.setData( variables.methods[arguments.missingMethodName]['#firstKey#'] ) />
						
						<!--- and now we can safely return default empty set in the absence of the webservice to describe it --->
						<cfset variables.methods[arguments.missingMethodName][cacheKey] = defaultSet.getEmptyData() />

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
	
	<cffunction name="GetDebugInternals" returntype="struct" access="public" output="false">
		
		<cfreturn variables />
	</cffunction>

</cfcomponent>