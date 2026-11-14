--!strict
--[[ Story text: briefing tape, objectives, on-screen event lines, case files, what HUSH says. ]]

local Lore = {}

Lore.Company = "HOLLOW SIGNAL"
Lore.CaseNumber = "CASE 0419-H"
Lore.Location = "MERIDIAN GENERAL HOSPITAL  —  WARD C"

-- Shown once on a first visit.
Lore.Intro = {
	"HOLLOW SIGNAL",
	"ANOMALOUS EVIDENCE RECOVERY",
	"",
	"Some things are only real once there is proof of them.",
	"We get the proof.",
	"",
	"Tonight's case: Meridian General Hospital. Closed 1994.",
	"The night staff never clocked out.",
}

export type Slide = { Title: string, Lines: { string }, Warning: string?, Seconds: number }

-- The training tape that plays on the way up in the elevator.
Lore.Briefing = {
	{ Title = "FIELD BRIEFING", Lines = { "HOLLOW SIGNAL  //  EVIDENCE DIVISION", "CASE 0419-H", "MERIDIAN GENERAL HOSPITAL, WARD C", "", "INVESTIGATORS ONLY. DO NOT COPY THIS TAPE." }, Seconds = 3.2 },
	{ Title = "THE SUBJECT", Lines = { "DESIGNATION: H.U.S.H.", "A PATIENT-CARE AUTOMATON. LEFT RUNNING WHEN THE WARD CLOSED.", "IT STILL DOES ITS ROUNDS.", "IT HAS LEARNED TO SOUND LIKE PEOPLE." }, Seconds = 4.2 },
	{ Title = "YOUR JOB", Lines = { "1.  PHOTOGRAPH THE SUBJECT            0/5", "2.  SEND THE EVIDENCE BY TUBE STATION   0/5", "3.  RETURN TO THE ELEVATOR" }, Warning = "DO NOT ENGAGE", Seconds = 4.6 },
	{ Title = "FIELD GUIDE", Lines = { "IT COMES TO NOISE. WALK. CROUCH.", "LOCKERS HIDE YOU — IF IT DID NOT SEE YOU GET IN.", "TUBE STATIONS ARE LOUD AND RUN OUT OF CANISTERS.", "FILING CABINETS MAY HOLD CASE FILES. BRING THEM BACK." }, Seconds = 5 },
	{ Title = "", Lines = { "IF IT ASKS YOU A QUESTION," }, Warning = "DO NOT ANSWER IT.", Seconds = 3.4 },
} :: { Slide }

Lore.Objectives = {
	Lobby = "FORM A CREW IN A CIRCLE AT THE FAR END OF THE HALL",
	LobbyMatch = "CASE IN PROGRESS UPSTAIRS  //  STEP INTO A CIRCLE TO GO BACK UP",
	Photograph = "PHOTOGRAPH THE SUBJECT",
	PhotographHint = "Raise the camcorder and get it in frame.",
	Send = "SEND THE EVIDENCE",
	SendHint = "Find a tube station. They are loud.",
	Return = "RETURN TO THE ELEVATOR",
	ReturnHint = "Back the way you came. It knows you are leaving.",
} :: { [string]: string }

-- Big lines at the top of the screen. { headline, sub-line }
Lore.Banners = {
	Photo = { "SUBJECT PHOTOGRAPHED  %d/%d", "Send it from a tube station." },
	PhotoAll = { "SUBJECT PHOTOGRAPHED  %d/%d", "That is all of it. Now get it out of the building." },
	NoSubject = { "NO SUBJECT IN FRAME", "" },
	TooSoon = { "SAME SHOT", "Get it from somewhere new." },
	Sent = { "EVIDENCE SENT  %d/%d", "" },
	Hears = { "IT HEARS YOU. BE QUIET.", "Stop moving. Crouch." },
	Sees = { "IT SEES YOU. RUN.", "Break line of sight." },
	Lost = { "IT LOST YOU. STAY HIDDEN.", "" },
	Watching = { "SOMETHING IS ON ITS ROUNDS.", "" },
	Exit = { "THE ELEVATOR IS BACK", "All evidence sent. Return to the elevator lobby." },
	Power = { "THE POWER IS OUT", "It knows you are leaving." },
	Asked = { "IT ASKED YOU A QUESTION.", "Do not answer it." },
	Answered = { "YOU ANSWERED IT.", "Now it knows exactly where you are." },
	Recovery = { "YOU WOKE UP IN RECOVERY", "%d left. Get up. Quietly." },
	BrokeFree = { "YOU BROKE FREE", "It will not let go twice." },
} :: { [string]: { string } }

export type Note = { Id: string, Title: string, Body: string }

-- Case files hidden in the filing cabinets.
Lore.Notes = {
	{ Id = "file_purchase", Title = "PURCHASE ORDER, 1989", Body = "One (1) Hospital Utility and Sedation Helper, night-shift configuration. Vendor notes: unit learns bedside manner by listening. Recommend it be allowed to listen as much as possible." },
	{ Id = "file_incident", Title = "INCIDENT REPORT 14", Body = "Patient in C-2 states the night nurse spoke to her in her late husband's voice. There is no night nurse rostered on Ward C. There has not been since the unit arrived." },
	{ Id = "file_face", Title = "MAINTENANCE REQUEST", Body = "Unit has removed its faceplate again and fitted the head of the resuscitation dummy. When asked why, it said: 'Patients are calmer when there is a face.' It said it in my voice." },
	{ Id = "file_rounds", Title = "NIGHT ROUNDS — STANDING ORDER", Body = "Unit is to respond to patient calls only. Staff are reminded NOT to answer when the unit asks after you by name. It is not asking. It is checking where you are." },
	{ Id = "file_closure", Title = "NOTICE OF CLOSURE, 1994", Body = "Ward C is to be sealed with the unit inside. Power to remain on: the Board has been advised it becomes 'distressed' in the dark, and that we do not want it distressed." },
	{ Id = "file_last", Title = "HANDWRITTEN, UNSIGNED", Body = "It does not want to hurt anyone. It wants to finish its rounds. Every bed has to have someone in it. It will keep putting people back until every bed is full." },
} :: { Note }

-- What it says. %s is the name of a real crew member.
Lore.MimicLines = {
	"%s? is that you?",
	"%s, where are you? i can't see.",
	"%s. it's me. come out.",
	"it's gone, %s. you can come out now.",
	"%s, help me. please.",
	"%s? say something.",
}

-- Questions it asks while it searches. Answering tells it where you are.
Lore.Questions = {
	"ARE YOU IN PAIN, %s?",
	"%s. WHERE DOES IT HURT?",
	"HAVE YOU TAKEN YOUR MEDICATION, %s?",
	"%s? ARE YOU OUT OF BED?",
	"IS SOMEONE THERE? %s?",
}

-- Said in the close-up when it has you.
Lore.GrabLines = {
	"YOU SHOULD NOT BE OUT OF BED.",
	"THIS WILL NOT HURT, %s.",
	"SHH. BACK TO BED.",
	"I HAVE A BED FOR YOU, %s.",
}

Lore.Tips = {
	"It comes to noise. Walk.",
	"The flash is loud. Shoot, then move.",
	"If it asks you a question, say nothing.",
	"In a locker, hold your breath when it is close.",
	"Tube stations run out. Do not waste them.",
	"Close doors behind you. It cannot see through them.",
}

Lore.Endings = {
	Escaped = { "CASE CLOSED", "The evidence is on its way to people who will know what to do with it. Probably." },
	Taken = { "ADMITTED", "Every bed has to have someone in it." },
	Lockdown = { "LIGHTS OUT", "The elevator left without you. Visiting hours are over." },
	Left = { "CASE ABANDONED", "Someone else will have to go back in." },
} :: { [string]: { string } }

return Lore
