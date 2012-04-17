<cfcomponent output="false">
	
	<cffunction name="setData" returntype="void" access="public" output="false">
		<cfargument name="data" type="any" required="true" />
		
		<cfset variables.cacheData = arguments.data />
	</cffunction>

	<cffunction name="getEmptyData" returntype="any" access="public" output="false">
		
		<cfset var aKey = '' />
		<cfset var emptydata = 0 />
		<cfset var fulltype = variables.cacheData.GetClass() />
		<cfset var type = ReReplace('#fullType#','\w+\s\w+\.\w+\.(\w+)','\1','ONE') />

		<cfswitch expression="#type#">

			<cfcase value="Struct">
				
				<!--- create a struct of empty keys that match the data's keys --->
				<cfset emptydata = StructNew() />

				<cfloop list="#StructKeyList( variables.cacheData )#" index="aKey">
					<cfset emptydata['#aKey#'] = '' />
				</cfloop>
			
			</cfcase>
			
			<cfcase value="QueryTable">
				
				<!--- create an empty query from a new column list --->
				<cfset emptydata = QueryNew( variables.cacheData.ColumnList ) />
			
			</cfcase>
			
			<cfdefaultcase>
				<cfthrow message="Unknown Type" detail="getEmptySet was passsed a type (#type#) that is unknown and cannot be defaulted." />
			</cfdefaultcase>
					
		</cfswitch>

		<cfreturn emptydata />
	</cffunction>

</cfcomponent>