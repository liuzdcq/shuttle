property checkCount : 0

on checkResult(condition, messageText)
	set checkCount to checkCount + 1
	if not condition then error ("FAIL: " & messageText) number 1
end checkResult

on run arguments
	set implementation to load script (POSIX file (item 1 of arguments))
	-- These operations replace only Terminal I/O. The production appearance
	-- handler and its error boundaries run unchanged from the compiled script.
	script fakeTerminal
		property profileError : 0
		property titleError : 0
		property profileCalls : 0
		property titleCalls : 0
		property appliedProfile : ""
		property appliedTitle : ""
		on applyProfile(targetTab, profileName)
			set profileCalls to profileCalls + 1
			if profileError is not 0 then error "Simulated Terminal profile failure" number profileError
			set appliedProfile to profileName
		end applyProfile
		on applyTitle(targetTab, tabTitle)
			set titleCalls to titleCalls + 1
			if titleError is not 0 then error "Simulated Terminal title failure" number titleError
			set appliedTitle to tabTitle
		end applyTitle
		on resetCalls()
			set profileCalls to 0
			set titleCalls to 0
			set profileError to 0
			set titleError to 0
		end resetCalls
	end script

	repeat with failureCode in {-1728, -10006}
		resetCalls() of fakeTerminal
		set profileError of fakeTerminal to contents of failureCode
		applyAppearance(missing value, "dark", "Connected host", fakeTerminal) of implementation
		my checkResult((profileCalls of fakeTerminal is 1), "a failed profile assignment is attempted only once")
		my checkResult((titleCalls of fakeTerminal is 1), "profile failure still allows setting the title")
		my checkResult((appliedTitle of fakeTerminal is "Connected host"), "the requested title survives a profile failure")
	end repeat

	resetCalls() of fakeTerminal
	applyAppearance(missing value, "", "Default profile", fakeTerminal) of implementation
	my checkResult((profileCalls of fakeTerminal is 0), "omitted theme preserves the current Terminal profile")
	my checkResult((titleCalls of fakeTerminal is 1), "omitted theme still sets the title")

	resetCalls() of fakeTerminal
	applyAppearance(missing value, "dark", "Custom profile", fakeTerminal) of implementation
	my checkResult((appliedProfile of fakeTerminal is "dark"), "an existing custom profile is applied")
	my checkResult((profileCalls of fakeTerminal is 1 and titleCalls of fakeTerminal is 1), "successful appearance is applied once")

	resetCalls() of fakeTerminal
	set titleError of fakeTerminal to -10006
	applyAppearance(missing value, "dark", "Title failure", fakeTerminal) of implementation
	my checkResult((profileCalls of fakeTerminal is 1 and titleCalls of fakeTerminal is 1), "a title failure does not retry appearance or the command")

	repeat with failureCode in {-1743, -10004, -25211}
		repeat with failedOperation in {"profile", "title"}
			resetCalls() of fakeTerminal
			if contents of failedOperation is "profile" then
				set profileError of fakeTerminal to contents of failureCode
			else
				set titleError of fakeTerminal to contents of failureCode
			end if
			try
				applyAppearance(missing value, "dark", "Denied", fakeTerminal) of implementation
				error "Authorization error was swallowed" number 1
			on error errorMessage number errorNumber
				my checkResult((errorNumber is contents of failureCode), "authorization errors remain visible")
			end try
		end repeat
	end repeat

	return "PASS: " & checkCount & " Terminal appearance checks"
end run
