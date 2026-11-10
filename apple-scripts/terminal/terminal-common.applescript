-- Appearance is optional. A command that has already started must not be
-- reported as failed just because a profile is missing or cannot be applied.
-- The operations argument also allows these boundaries to be tested without
-- opening Terminal, changing profiles, or executing a user's commands.
on applyAppearance(targetTab, profileName, tabTitle, operations)
	if profileName is not "" then
		try
			applyProfile(targetTab, profileName) of operations
		on error errorMessage number errorNumber
			my handleAppearanceError(errorMessage, errorNumber)
		end try
	end if
	try
		applyTitle(targetTab, tabTitle) of operations
	on error errorMessage number errorNumber
		my handleAppearanceError(errorMessage, errorNumber)
	end try
end applyAppearance

on handleAppearanceError(errorMessage, errorNumber)
	-- Keep genuine authorization failures visible to the caller.
	if errorNumber is in {-1743, -10004, -25211} then
		error errorMessage number errorNumber
	end if
	log ("Shuttle: optional Terminal appearance was not applied: " & errorMessage)
end handleAppearanceError

on applyProfile(targetTab, profileName)
	tell application "Terminal"
		-- Resolve a real profile before assigning it to the tab. A missing name
		-- leaves Terminal's current/default appearance intact.
		set requestedProfile to first settings set whose name is profileName
		set current settings of targetTab to requestedProfile
	end tell
end applyProfile

on applyTitle(targetTab, tabTitle)
	tell application "Terminal"
		set title displays custom title of targetTab to true
		set custom title of targetTab to tabTitle
	end tell
end applyTitle
