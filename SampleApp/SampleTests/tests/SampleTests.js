#import "../Common.js";

app = appmap.apps["SampleApp"];


automator.createScenario("Press button to populate label", ["test"])
	.withStep(app.homeScreen.pressButton)
	.withStep(app.homeScreen.verifyLabelString, {labelText : "Button Pressed"})
	.withStep(app.homeScreen.clearLabel);
	

automator.createScenario("Press button to populate label with mocked text", ["mocked"])
	.withStep(app.homeScreen.mockLabelText, {labelText : "Mocked Pressed"})
	.withStep(app.homeScreen.pressButton)
	.withStep(app.homeScreen.verifyLabelString, {labelText : "Mocked Pressed"})
	.withStep(app.homeScreen.clearLabel)
	
	