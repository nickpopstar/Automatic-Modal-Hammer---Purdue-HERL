classdef SAMH_GUI_V2 < matlab.apps.AppBase

    % ---------------------------------------------------------------------
    % Properties: Shared Resources (Network & State)
    % ---------------------------------------------------------------------
    properties (Access = public)
        % NETWORK (Shared across all views)
        TcpConnection               
        PiIP = "192.168.10.2"       % REPLACE with your Pi's IP
        PiPort = 5000               % Port
        
        % APP WINDOWS (We keep all three alive)
        Figure1                     matlab.ui.Figure % View 1: Zeroing
        Figure2                     matlab.ui.Figure % View 2: Calibration
        Figure3                     matlab.ui.Figure % View 3: Testing
    end

    % ---------------------------------------------------------------------
    % Properties: Components for View 1 (Zeroing Protocol)
    % ---------------------------------------------------------------------
    properties (Access = public)
        ContinueButton              matlab.ui.control.Button
        StepCCWButton               matlab.ui.control.Button
        StepCWButton                matlab.ui.control.Button
        Step5CCWButton              matlab.ui.control.Button
        Step5CWButton               matlab.ui.control.Button
        Step180DegButton            matlab.ui.control.Button
        FineLabel                   matlab.ui.control.Label
        EngageButton                matlab.ui.control.StateButton
        DisengageButton             matlab.ui.control.StateButton
        InitialLabel                matlab.ui.control.Label
        DisconnectButton            matlab.ui.control.Button
    end

    % ---------------------------------------------------------------------
    % Properties: Components for View 2 (Calibration Cycle)
    % ---------------------------------------------------------------------
    properties (Access = public)
        PercentToleranceField       matlab.ui.control.NumericEditField
        ToleranceLabel              matlab.ui.control.Label
        ApplyToleranceButton        matlab.ui.control.Button
        RunTestButton               matlab.ui.control.Button
        TrueForceField              matlab.ui.control.EditField
        TrueForceLabel              matlab.ui.control.Label
        ApplyTrueForceButton        matlab.ui.control.Button
        YesButton                   matlab.ui.control.Button
        DoubleHitLabel              matlab.ui.control.Label
        DesiredForceField           matlab.ui.control.NumericEditField
        DesiredForceLabel           matlab.ui.control.Label
        ApplyDesiredButton          matlab.ui.control.Button
        CalibrationLabel            matlab.ui.control.Label
        NumCalTestsLabel            matlab.ui.control.Label
        NumCalTestsField            matlab.ui.control.NumericEditField
        BackButton_Calibration      matlab.ui.control.Button
        HammerTipDropDown           matlab.ui.control.DropDown
        HammerTipLabel              matlab.ui.control.Label
    end

    % ---------------------------------------------------------------------
    % Properties: Components for View 3 (Testing Parameters)
    % ---------------------------------------------------------------------
    properties (Access = public)
        TestingLabel                matlab.ui.control.Label
        NumberOfHitsLabel           matlab.ui.control.Label
        NumberOfHitsField           matlab.ui.control.NumericEditField
        ApplyHitsButton             matlab.ui.control.Button
        TimeLabel                   matlab.ui.control.Label
        TimeField                   matlab.ui.control.NumericEditField
        ApplyTimeButton             matlab.ui.control.Button
        StartTestButton             matlab.ui.control.Button
        StopButton                  matlab.ui.control.Button
        EndTestButton               matlab.ui.control.Button
        
        % new
        NumberOfTestsLabel          matlab.ui.control.Label
        NumberOfTestsField          matlab.ui.control.NumericEditField
        ApplyTestsButton            matlab.ui.control.Button
        ForceIncrementLabel         matlab.ui.control.Label
        ForceIncrementField         matlab.ui.control.NumericEditField
        ApplyIncrementButton        matlab.ui.control.Button
        
        BackButton_Testing          matlab.ui.control.Button
    end

    % ---------------------------------------------------------------------
    % Helper Methods (Communication Layer)
    % ---------------------------------------------------------------------
    methods (Access = private)
        
        % Connect to the Pi's Server
        function connectToPi(app)
    if isempty(app.TcpConnection)
        try
            % FIX: Set Timeout INSIDE the creation function
            app.TcpConnection = tcpclient(app.PiIP, app.PiPort, 'ConnectTimeout', 3);
            
            disp("Connected to Raspberry Pi.");
        catch ME % Capture the actual error message into 'ME'
            
            % Debugging: Print the REAL reason for the failure to the command window
            disp("Error Message: " + ME.message); 
            
            % cleanup: If we failed, make sure the variable is empty so we can try again
            app.TcpConnection = []; 

            % Alert on the currently visible figure
            if strcmp(app.Figure1.Visible, 'on')
                target = app.Figure1;
            elseif strcmp(app.Figure2.Visible, 'on')
                target = app.Figure2;
            else
                target = app.Figure3;
            end
            uialert(target, 'Could not connect to Raspberry Pi.', 'Connection Error');
        end
    end
end

        % Send command in explicit UTF-8 Format
        function sendCommand(app, cmdString)
            if ~isempty(app.TcpConnection)
                try
                    % 1. Combine the command with a Newline character
                    fullMsg = cmdString + newline;
                    
                    % 2. Convert the string to explicit UTF-8 bytes (uint8)
                    utf8Bytes = unicode2native(fullMsg, 'UTF-8');
                    
                    % 3. Write the raw bytes to the TCP connection
                    write(app.TcpConnection, utf8Bytes);
                    
                    fprintf("Sent (UTF-8): %s\n", cmdString); 
                catch
                    disp("Error: Connection to Pi lost.");
                end
            else
                disp("Error: Not connected to Pi.");
            end
        end
        
        % Switch Views
        function switchView(app, fromFigure, toFigure)
            fromFigure.Visible = 'off';
            toFigure.Visible = 'on';
            toFigure.Position(1:2) = fromFigure.Position(1:2);
        end
    end

    % ---------------------------------------------------------------------
    % Callbacks: View 1 (Zeroing Protocol)
    % ---------------------------------------------------------------------
    methods (Access = private)
        function EngageButtonValueChanged(app, event)
            app.DisengageButton.Value = 0; 
            app.sendCommand("ENGAGE");          
        end

        function DisengageButtonValueChanged(app, event)
            app.EngageButton.Value = 0;    
            app.sendCommand("DISENGAGE");       
        end

        function StepCWButtonPushed(app, event)
            app.sendCommand("CW-1");
        end

        function StepCCWButtonPushed(app, event)
            app.sendCommand("CCW-1");
        end

        function Step5CCWButtonPushed(app, event)
            app.sendCommand("CCW-5");
        end

        function Step5CWButtonPushed(app, event)
            app.sendCommand("CW-5");
        end

        function Step180DegButtonPushed(app, event)
            app.sendCommand("MOVE_180_DEG");
        end
        function ContinueButtonPushed(app, event)
            app.switchView(app.Figure1, app.Figure2);
        end
        
        function DisconnectButtonPushed(app, event)
            app.sendCommand("DISCONNECT");
            delete(app);
        end
        
    end

    % ---------------------------------------------------------------------
    % Callbacks: View 2 (Calibration Cycle)
    % ---------------------------------------------------------------------
    methods (Access = private)
        function HammerTipColorChanged(app, event)
            color = app.HammerTipDropDown.Value;
            app.sendCommand("SET_TIP_COLOR" + "," + color);
        end

        function ApplyDesiredForcePushed(app, event)
            val = app.DesiredForceField.Value;
            tipType = app.HammerTipDropDown.Value;
        
            % Determine range based on the selected hammer type
            if contains(tipType, 'Small Hammer')
                minForce = 15;
                maxForce = 200;
            elseif contains(tipType, 'Big Hammer')
                minForce = 40;
                maxForce = 800;
            else
                % Logic for 'empty' or undefined tips
                uialert(app.Figure2, 'Please select a hammer tip first.', 'Selection Error');
                return;
            end
        
            % Validate the input value
            if val >= minForce && val <= maxForce
                app.sendCommand("SET_FORCE" + "," + num2str(val));
            else
                % Alert the user if the input is out of bounds
                errorMessage = sprintf('Force must be between %d and %d N for this hammer.', minForce, maxForce);
                uialert(app.Figure2, errorMessage, 'Invalid Force Range');
            end
        end

        function ApplyTolerancePushed(app, event)
            val = app.PercentToleranceField.Value;
            minTolerancePercentValue = 2;
            if val >= minTolerancePercentValue
                app.sendCommand("SET_TOLERANCE" + "," + num2str(val));
            else
                errorMessage = sprintf('Tolerance must be at least %d%%.', minTolerancePercentValue);
                uialert(app.Figure2, errorMessage, 'Invalid Tolerance');
            end
        end

    %    function NumCalTestsPushed(app, event)
     %       val = app.NumCalTestsField.Value;
      %      app.sendCommand("SET_NUM_CAL_HITS" + "," + num2str(val));
       % end

        function RunTestButtonPushed(app, event)
            val = app.NumCalTestsField.Value;
            app.sendCommand("RUN_TEST" + "," + num2str(val));
        end

        function YesButtonPushed(app, event)
            app.sendCommand("DOUBLE_HIT_YES");
            disp("Moved 1 step backwards")
        end

        function EvaluateCalibrationButtonPushed(app, event)
            % 1. Get the number of expected tests
            num_tests = app.NumCalTestsField.Value;

            % 2. Get the true force string and parse it
            force_str = app.TrueForceField.Value;
            % Split the string by commas and convert to an array of numbers
            force_vals = str2double(split(force_str, ','));

            % Remove any NaN values in case of trailing commas or spaces
            force_vals = force_vals(~isnan(force_vals));

            % 3. Validate the number of inputs
            if length(force_vals) ~= num_tests
                uialert(app.Figure2, sprintf('Expected %d inputs, but received %d. Please check your comma-separated values.', num_tests, length(force_vals)), 'Input Error');
                return;
            end

            % 4. Calculate Average
            avg_force = mean(force_vals);
            desired_force = app.DesiredForceField.Value; 
            percent_tolerance = app.PercentToleranceField.Value;
            app.sendCommand("TRUE_FORCE" + "," + num2str(avg_force));

            % 5. Check Tolerance
            error_pct = abs(avg_force - desired_force) / desired_force * 100;

            if error_pct > percent_tolerance
                % Failed tolerance - Use uiconfirm instead of uialert
                msg = sprintf('Average Force (%.2f N) failed desired %.1f%% tolerance check (Actual: %.1f%%). Run a new calibrated test hit?', avg_force, percent_tolerance, error_pct);
                selection = uiconfirm(app.Figure2, msg, 'Calibration Failed', ...
                    'Options', {'Yes', 'No'}, ...
                    'DefaultOption', 1, 'CancelOption', 2);

                if strcmp(selection, 'Yes')
                    app.sendCommand("RUN_TEST" + "," + num2str(num_tests) + "," + "CALIBRATE_FORCE");
                end
            else
                uialert(app.Figure2, 'Calibration Passed! Switching to next view', 'Success', ...
            'Icon', 'success', ...
            'CloseFcn', @(src, event) app.switchView(app.Figure2, app.Figure3));
            end
        end

        % Back Button (Fig 2 -> Fig 1)
        function BackToZeroingPushed(app, event)
            app.switchView(app.Figure2, app.Figure1);
        end
    end

    % ---------------------------------------------------------------------
    % Callbacks: View 3 (Testing Parameters)
    % ---------------------------------------------------------------------
    methods (Access = private)
        
        function ApplyHitsPushed(app, event)
            val = app.NumberOfHitsField.Value;
            app.sendCommand("SET_HITS" + "," + num2str(val));
        end

        function ApplyTimePushed(app, event)
            val = app.TimeField.Value;
            app.sendCommand("SET_TIME" + "," + num2str(val));
        end

        % --- NEW CALLBACK: Apply Number of Tests ---
        function ApplyTestsPushed(app, event)
            val = app.NumberOfTestsField.Value;
            app.sendCommand("SET_NUM_TESTS" + "," + num2str(val));
        end

        % --- NEW CALLBACK: Apply Force Increment ---
        function ApplyIncrementPushed(app, event)
            val = app.ForceIncrementField.Value;
            app.sendCommand("SET_INCREMENT" + "," + num2str(val));
        end

        % --- UPDATED: Start Test Logic ---
        function StartTestPushed(app, event)
            numTests = app.NumberOfTestsField.Value;
            increment = app.ForceIncrementField.Value;
            
            % Logic: If Tests > 1, Increment must be valid (>0)
            if numTests > 1 && (isempty(increment) || increment <= 0)
                uialert(app.Figure3, ...
                    "If Number of Tests is greater than 1, Force Increment must be >0.", ...
                    "Missing Parameter", 'Icon', 'warning');
            else
                % If checks pass, send start command
                app.sendCommand("START_TEST");
            end
        end

        function StopButtonPushed(app, event)
            app.sendCommand("STOP_TEST");
        end
        
        function EndTestButtonPushed(app, event)
            app.sendCommand("DISCONNECT"); 
            delete(app); 
        end
        
        % Back Button (Fig 3 -> Fig 2)
        function BackToCalibrationPushed(app, event)
            app.switchView(app.Figure3, app.Figure2);
        end
    end

    % ---------------------------------------------------------------------
    % UI Creation (Layouts)
    % ---------------------------------------------------------------------
    methods (Access = private)
        
        function createComponents(app)
            % =============================================================
            % FIGURE 1: Zeroing Protocol
            % =============================================================
            app.Figure1 = uifigure('Visible', 'off');
            app.Figure1.Position = [100 100 269 475];
            app.Figure1.Name = 'Zeroing Protocol';
            app.Figure1.CloseRequestFcn = createCallbackFcn(app, @delete, true);

            app.InitialLabel = uilabel(app.Figure1);
            app.InitialLabel.FontSize = 24;
            app.InitialLabel.Position = [44 406 185 31];
            app.InitialLabel.Text = 'Initial Positioning';

            app.DisengageButton = uibutton(app.Figure1, 'state');
            app.DisengageButton.ValueChangedFcn = createCallbackFcn(app, @DisengageButtonValueChanged, true);
            app.DisengageButton.Text = 'Disengage Motor';
            app.DisengageButton.Position = [84 364 105 23];

            app.EngageButton = uibutton(app.Figure1, 'state');
            app.EngageButton.ValueChangedFcn = createCallbackFcn(app, @EngageButtonValueChanged, true);
            app.EngageButton.Text = 'Engage Motor';
            app.EngageButton.Position = [84 329 105 23];

            app.FineLabel = uilabel(app.Figure1);
            app.FineLabel.FontSize = 24;
            app.FineLabel.Position = [44 285 176 31];
            app.FineLabel.Text = 'Fine Positioning';

            app.StepCWButton = uibutton(app.Figure1, 'push');
            app.StepCWButton.ButtonPushedFcn = createCallbackFcn(app, @StepCWButtonPushed, true);
            app.StepCWButton.Position = [78 245 110 23];
            app.StepCWButton.Text = '1 Step Clockwise';

            app.StepCCWButton = uibutton(app.Figure1, 'push');
            app.StepCCWButton.ButtonPushedFcn = createCallbackFcn(app, @StepCCWButtonPushed, true);
            app.StepCCWButton.Position = [78 215 110 23];
            app.StepCCWButton.Text = '1 Step CCW';

            app.Step5CWButton = uibutton(app.Figure1, 'push');
            app.Step5CWButton.ButtonPushedFcn = createCallbackFcn(app, @Step5CWButtonPushed, true);
            app.Step5CWButton.Position = [78 185 110 23];
            app.Step5CWButton.Text = '5 Step Clockwise';

            app.Step5CCWButton = uibutton(app.Figure1, 'push');
            app.Step5CCWButton.ButtonPushedFcn = createCallbackFcn(app, @Step5CCWButtonPushed, true);
            app.Step5CCWButton.Position = [78 155 110 23];
            app.Step5CCWButton.Text = '5 Step CCW';
            
            app.Step180DegButton = uibutton(app.Figure1, 'push');
            app.Step180DegButton.ButtonPushedFcn = createCallbackFcn(app, @Step180DegButtonPushed, true);
            app.Step180DegButton.Position = [78 125 110 23];
            app.Step180DegButton.Text = 'Move -180 Degrees';

            app.ContinueButton = uibutton(app.Figure1, 'push');
            app.ContinueButton.ButtonPushedFcn = createCallbackFcn(app, @ContinueButtonPushed, true);
            app.ContinueButton.BackgroundColor = [0.3294 0.5804 0];
            app.ContinueButton.FontSize = 24;
            app.ContinueButton.FontWeight = 'bold';
            app.ContinueButton.Position = [70 60 125 70];
            app.ContinueButton.Text = 'Continue';

            % Disconnect Button
            app.DisconnectButton = uibutton(app.Figure1, 'push');
            app.DisconnectButton.ButtonPushedFcn = createCallbackFcn(app, @DisconnectButtonPushed, true);
            app.DisconnectButton.BackgroundColor = [0.8706 0 0];
            app.DisconnectButton.FontColor = [1 1 1];
            app.DisconnectButton.FontSize = 14;
            app.DisconnectButton.Position = [10 10 90 40];
            app.DisconnectButton.Text = 'Disconnect';

            % =============================================================
            % FIGURE 2: Calibration Cycle
            % =============================================================
            app.Figure2 = uifigure('Visible', 'off');
            app.Figure2.Position = [100 100 430 480]; 
            app.Figure2.Name = 'Calibration Cycle';
            app.Figure2.CloseRequestFcn = createCallbackFcn(app, @delete, true);
            
            app.CalibrationLabel = uilabel(app.Figure2);
            app.CalibrationLabel.FontSize = 24;
            app.CalibrationLabel.Position = [123 420 186 31];
            app.CalibrationLabel.Text = 'Calibration Cycle';

            app.HammerTipLabel = uilabel(app.Figure2);
            app.HammerTipLabel.HorizontalAlignment = 'right';
            app.HammerTipLabel.Position = [60 375 114 22];
            app.HammerTipLabel.Text = 'Hammer Tip Type';
        
            app.HammerTipDropDown = uidropdown(app.Figure2);
            app.HammerTipDropDown.Items = {'empty', 'Big Hammer: red', 'Big Hammer: green', 'Big Hammer: orange', 'Small Hammer: metal', 'Small Hammer: plastic'};
            app.HammerTipDropDown.ValueChangedFcn = createCallbackFcn(app, @HammerTipColorChanged, true);
            app.HammerTipDropDown.Position = [189 375 100 22];
            
            app.DesiredForceLabel = uilabel(app.Figure2);
            desired_force_y = 335;
            app.DesiredForceLabel.HorizontalAlignment = 'right';
            app.DesiredForceLabel.Position = [60 desired_force_y 114 22];
            app.DesiredForceLabel.Text = 'Desired Force Value';
            app.DesiredForceField = uieditfield(app.Figure2, 'numeric');
            app.DesiredForceField.Position = [189 desired_force_y 100 22];
            app.ApplyDesiredButton = uibutton(app.Figure2, 'push');
            app.ApplyDesiredButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyDesiredForcePushed, true);
            app.ApplyDesiredButton.Position = [304 desired_force_y 46 23];
            app.ApplyDesiredButton.Text = 'Apply';

            app.ToleranceLabel = uilabel(app.Figure2);
            tolerance_y = 295;
            app.ToleranceLabel.HorizontalAlignment = 'right';
            app.ToleranceLabel.Position = [69 tolerance_y 105 22];
            app.ToleranceLabel.Text = 'Percent Tolerance ';
            app.PercentToleranceField = uieditfield(app.Figure2, 'numeric');
            app.PercentToleranceField.Position = [189 tolerance_y 100 22];
            app.ApplyToleranceButton = uibutton(app.Figure2, 'push');
            app.ApplyToleranceButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyTolerancePushed, true);
            app.ApplyToleranceButton.Position = [304 tolerance_y 46 23];
            app.ApplyToleranceButton.Text = 'Apply';

            app.NumCalTestsLabel = uilabel(app.Figure2);
            numCalTests_y = 255;
            app.NumCalTestsLabel.HorizontalAlignment = 'right';
            app.NumCalTestsLabel.Position = [19 numCalTests_y 155 22];
            app.NumCalTestsLabel.Text = 'Number of Cal. Tests';
            app.NumCalTestsField = uieditfield(app.Figure2, 'numeric');
            app.NumCalTestsField.Position = [189 numCalTests_y 100 22];
            app.NumCalTestsField.Value = 1;

            app.RunTestButton = uibutton(app.Figure2, 'push');
            app.RunTestButton.ButtonPushedFcn = createCallbackFcn(app, @RunTestButtonPushed, true);
            app.RunTestButton.BackgroundColor = [0.1176 0.6392 0];
            app.RunTestButton.Position = [161 185 109 46];
            app.RunTestButton.Text = 'Run Test Cycle';

            app.DoubleHitLabel = uilabel(app.Figure2);
            app.DoubleHitLabel.Position = [141 145 158 22];
            app.DoubleHitLabel.Text = 'Did the Hammer Double Hit?';
            app.YesButton = uibutton(app.Figure2, 'push');
            app.YesButton.ButtonPushedFcn = createCallbackFcn(app, @YesButtonPushed, true);
            app.YesButton.Position = [161 110 100 23];
            app.YesButton.Text = 'Yes';

            app.TrueForceLabel = uilabel(app.Figure2);
            app.TrueForceLabel.HorizontalAlignment = 'right';
            app.TrueForceLabel.WordWrap = 'on';
            app.TrueForceLabel.Position = [30 65 125 40];
            app.TrueForceLabel.Text = 'True Force Values (F1, F2, ...)';
            app.TrueForceField = uieditfield(app.Figure2, 'text'); % Type set to text
            app.TrueForceField.Position = [160 65 120 22];
            app.ApplyTrueForceButton = uibutton(app.Figure2, 'push');
            app.ApplyTrueForceButton.ButtonPushedFcn = createCallbackFcn(app, @EvaluateCalibrationButtonPushed, true);
            app.ApplyTrueForceButton.Position = [295 65 100 23];
            app.ApplyTrueForceButton.Text = 'Evaluate';

            app.BackButton_Calibration = uibutton(app.Figure2, 'push');
            app.BackButton_Calibration.ButtonPushedFcn = createCallbackFcn(app, @BackToZeroingPushed, true);
            app.BackButton_Calibration.Position = [10 30 70 25]; 
            app.BackButton_Calibration.Text = '<-- Back';

            % =============================================================
            % FIGURE 3: Testing Parameters
            % =============================================================
            app.Figure3 = uifigure('Visible', 'off');
            app.Figure3.Position = [100 100 492 480]; % used to be 380
            app.Figure3.Name = 'Testing Parameters';
            app.Figure3.CloseRequestFcn = createCallbackFcn(app, @delete, true);

            app.TestingLabel = uilabel(app.Figure3);
            app.TestingLabel.FontSize = 24;
            app.TestingLabel.Position = [140 400 213 45];
            app.TestingLabel.Text = 'Testing Parameters';

            % Number of Hits
            app.NumberOfHitsLabel = uilabel(app.Figure3);
            app.NumberOfHitsLabel.HorizontalAlignment = 'right';
            app.NumberOfHitsLabel.Position = [125 240 88 22];
            app.NumberOfHitsLabel.Text = 'Number Of Hits';

            app.NumberOfHitsField = uieditfield(app.Figure3, 'numeric');
            app.NumberOfHitsField.Position = [228 240 100 22];

            app.ApplyHitsButton = uibutton(app.Figure3, 'push');
            app.ApplyHitsButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyHitsPushed, true);
            app.ApplyHitsButton.Position = [343 240 46 23];
            app.ApplyHitsButton.Text = 'Apply';

            % Time Between Hits
            app.TimeLabel = uilabel(app.Figure3);
            app.TimeLabel.HorizontalAlignment = 'right';
            app.TimeLabel.Position = [78 209 135 22];
            app.TimeLabel.Text = 'Time Between Hits (sec)';

            app.TimeField = uieditfield(app.Figure3, 'numeric');
            app.TimeField.Position = [228 209 100 22];

            app.ApplyTimeButton = uibutton(app.Figure3, 'push');
            app.ApplyTimeButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyTimePushed, true);
            app.ApplyTimeButton.Position = [343 209 46 23];
            app.ApplyTimeButton.Text = 'Apply';
            
            % New: number of tests
            app.NumberOfTestsLabel = uilabel(app.Figure3);
            app.NumberOfTestsLabel.HorizontalAlignment = 'right';
            app.NumberOfTestsLabel.Position = [78 300 135 22];
            app.NumberOfTestsLabel.Text = 'Number of Tests';
            app.NumberOfTestsField = uieditfield(app.Figure3, 'numeric');
            app.NumberOfTestsField.Position = [228 300 100 22];
            app.ApplyTestsButton = uibutton(app.Figure3, 'push');
            app.ApplyTestsButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyTestsPushed, true);
            app.ApplyTestsButton.Position = [343 300 46 23];
            app.ApplyTestsButton.Text = 'Apply';
            
            % 4. NEW: Force Increment
            app.ForceIncrementLabel = uilabel(app.Figure3);
            app.ForceIncrementLabel.HorizontalAlignment = 'right';
            app.ForceIncrementLabel.Position = [78 270 135 30];
            app.ForceIncrementLabel.Text = 'Force Increment (if applicable)';
            app.ForceIncrementLabel.WordWrap = 'on';
            app.ForceIncrementField = uieditfield(app.Figure3, 'numeric');
            app.ForceIncrementField.Position = [228 270 100 22];
            app.ApplyIncrementButton = uibutton(app.Figure3, 'push');
            app.ApplyIncrementButton.ButtonPushedFcn = createCallbackFcn(app, @ApplyIncrementPushed, true);
            app.ApplyIncrementButton.Position = [343 270 46 23];
            app.ApplyIncrementButton.Text = 'Apply';

            % Start Test
            app.StartTestButton = uibutton(app.Figure3, 'push');
            app.StartTestButton.ButtonPushedFcn = createCallbackFcn(app, @StartTestPushed, true);
            app.StartTestButton.BackgroundColor = [0 0.5882 0.0902];
            app.StartTestButton.FontSize = 18;
            app.StartTestButton.Position = [280 82 147 75];
            app.StartTestButton.Text = 'Start Test';

            % Stop Button
            app.StopButton = uibutton(app.Figure3, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.BackgroundColor = [0.8706 0 0];
            app.StopButton.FontSize = 18;
            app.StopButton.Position = [78 82 147 75];
            app.StopButton.Text = 'Stop';
            
            % End Test Button
            app.EndTestButton = uibutton(app.Figure3, 'push');
            app.EndTestButton.ButtonPushedFcn = createCallbackFcn(app, @EndTestButtonPushed, true);
            app.EndTestButton.BackgroundColor = [0.2 0.2 0.2]; 
            app.EndTestButton.FontColor = [1 1 1]; 
            app.EndTestButton.FontSize = 14;
            app.EndTestButton.Position = [171 20 150 40]; 
            app.EndTestButton.Text = 'End Test & Close';

            % Back Button (Testing -> Calibration)
            app.BackButton_Testing = uibutton(app.Figure3, 'push');
            app.BackButton_Testing.ButtonPushedFcn = createCallbackFcn(app, @BackToCalibrationPushed, true);
            app.BackButton_Testing.Position = [20 20 80 30]; 
            app.BackButton_Testing.Text = '<-- Back';

            % Initial State: Show Figure 1 only
            app.Figure1.Visible = 'on';
        end
    end

    % ---------------------------------------------------------------------
    % App Construction and Deletion
    % ---------------------------------------------------------------------
    methods (Access = public)
        
        function app = SAMH_GUI_V2
            createComponents(app)
            registerApp(app, app.Figure1)
            
            % Connect to Pi once at startup
            app.connectToPi();

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            % Clean up connection
            if ~isempty(app.TcpConnection)
                delete(app.TcpConnection);
            end
            % Delete all figures to close the app fully
            delete(app.Figure1)
            delete(app.Figure2)
            delete(app.Figure3)
        end
    end
end