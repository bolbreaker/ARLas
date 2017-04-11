classdef arlas < handle
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Class definition arlas
% For use with ARLas (Auditory Research Laboratory auditory software)
%
% Auditory Research Lab, The University of Iowa
% Deptartment of Communication Sciences & Disorders
% The University of Iowa
% Author: Shawn S. Goodman, PhD
% Date: September 14, 2016
% Last Updated: April 11, 2017
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
properties (SetAccess = private)
    arlasVersion = '2017.04.11';
    sep % path delimiter appriate for the current operating system 
    map % struct containing file paths
    initPath
    initFile
    home % current working directory, prior to starting arlas (will return here when exits)
    %----- handles for graphical user interface ----- -----    
    H % Figure handle ----- 
        guiSize
        CONTROL % CONTROL Panel -----
            h % control panel gui
            gui % dimensions of the control panel
            nButtons = 5; % number of buttons
            h_splash
            h_init % initialization button
            h_pause % calibrate button
            h_load % load button
            h_run % run button
            h_abort % abort button
        ATTEN_OUT % ATTEN_OUT Panel -----
            h_DACgain % figure for controlling DAC gain
            h_gainCh1
            h_gainCh2
            h_gainUp
            h_gainDn
            h_continue        
        VIEW % CURRENT pannel -----
    h_subjID
    h_subjLabel
    h_subjBox 
    h_expLabel
    h_expBox
    h_opLabel
    h_opBox
    enterSubjID
    h_enterSubjID
    subjID_OK
end
properties (SetAccess = public) 
    objInit % object of class initARLas (initialization)
    objPlayrec % object of class playrecARLas (play and record using playrec utility)
    initialized % whether the system is currently initialized
    killRun % whether the abort button has been pushed
    
    expFileName
    expPathName
    loaded % whether a calibration file is currently loaded
    subjectID
    experimentID
    operatorID    
end

methods
    function obj = arlas(~) % initialize object of class initARLas
        obj.sep = filesep; % get the path delimiter appropriate to the operating system being used
        dummy = which('arlas'); % get the location of the currently-running verison of arlas.m
        indx = length(dummy); % strip off the file name at the end
        stop = 0;
        while ~stop
            if strcmp(dummy(indx),obj.sep)
                stop = 1;
                dummy = dummy(1:indx); % location of arlas
                base = dummy(1:end-13); % base location is dummy less the 13 characters: Core\classes\
            end
            indx = indx - 1;
            if indx < 1
                errorTxt = {'  Issue: Unable to path location of currently running version of ARLas.'
                     '  Action: Aborting initialization.'
                     '  Location: arlas.arlas.'
                    };
                errorMsgARLas(errorTxt);
                return
            end
        end
        obj.home = pwd; % get the current working directory
        addpath(genpath(base)) % add all directories and subdirectories 
        cd(base) % change directory to the base location (will change directories back home upon exit)
        format compact % save space in command window
        % create a map to needed directories
        obj.map.calibrations = [base,'Peripheral',obj.sep,'calibrations',obj.sep];
        obj.map.experiments = [base,'Peripheral',obj.sep,'experiments',obj.sep];
        obj.map.sysConfigs = [base,'Peripheral',obj.sep,'sysConfigs',obj.sep];
        obj.map.data = [base,'Data',obj.sep];
        % check to make sure that these directories exist; if not, alert user
        errorTxt = {'  Issue: Unexpected ARLas directory structure found.'
             '  Action:  Aborting ARLas.'
             '  Location: arlas.initPlayrec.'
             '  Recommended Fix: Make sure the following ARLas structure exists:.'
             '  ------------------------------------ '
             '   ARLas (base directory)'
             '     \\Core'
             '         \\classes (* Note: The file arlas.m is located here.)'
             '             \\classSupport'
             '         \\general'
             '         \\gui'
             '         \\playrec'
             '     \\Peripheral'
             '         \\calibrations'
             '         \\experiments'
             '         \\sysConfigs'
             '     \\Data'
             '  ------------------------------------ '
            };
        OK = 1;
        if exist(obj.map.calibrations,'dir') ~= 7
            OK = 0;
        end
        if exist(obj.map.experiments,'dir') ~= 7
            OK = 0;
        end
        if exist(obj.map.sysConfigs,'dir') ~= 7
            OK = 0;
        end
        if exist(obj.map.data,'dir') ~= 7
            try 
                mkdir(obj.map.data)
                addpath(genpath(obj.map.data)) 
            catch
            end
        end
        if exist(obj.map.data,'dir') ~= 7
            OK = 0;
        end
        if OK == 0
            errorMsgARLas(errorTxt);
            return
        end
        obj.initPath = obj.map.sysConfigs;
        obj.initFile = 'newSysConfig.mat';
        obj.initGui % initialize the gui
    end  
    function abort(varargin) % instructions for aborting when gui closed
        try
            obj = varargin{1};
            cd(obj.home) % change directory to the home location 
        catch
        end
        try
            obj = varargin{1};
            delete(obj.objInit)
            delete(obj.objPlayrec)
            delete(obj.H)
            delete(obj);
        catch
            while gcf~=1 
                delete(gcf);
            end;
            delete(gcf);
        end
    end
    function initGui(varargin) % initialize the recording gui
        obj = varargin{1};
        try
            delete(obj.H)
        catch
        end
        % Create main figure -----
        %[left, bottom,width, height]
        obj.guiSize.width = 545; % figure width in pixels
        obj.guiSize.height = 620; %625; %675; %750;
        scrsz = get(0,'ScreenSize'); % get the current screen size
        obj.guiSize.left = round(scrsz(4) * .1); % location of left edge
        obj.guiSize.bottom = scrsz(4) * .1; % location of bottom
        overhang = (obj.guiSize.bottom + obj.guiSize.height)-scrsz(4); % adjust so gui doesn't hang off the top of the screen
        if overhang > 0 % if positive value (meaning figure is off the screen)
            overhang = overhang + 0; % give a little extra to account for top of the figure
            %if overhang <= obj.guiSize.bottom % try to fix this problem
                obj.guiSize.bottom = obj.guiSize.bottom - overhang; % correct for the overhang
            %else % otherwise, do the best you can
            %    obj.guiSize.bottom = 1; % put it as low as possible
            %end
        end
        rect = [obj.guiSize.left, obj.guiSize.bottom, obj.guiSize.width, obj.guiSize.height];
        obj.H = figure('Position',rect,'Color',[1 1 1],'Units','Pixels',...
            'CloseRequestFcn',@obj.abort,'Name',['ARLas  version ',obj.arlasVersion],...
            'NumberTitle','off','MenuBar','none','Resize','on','Color',[1 1 1],'Tag','ARLas');
        % create panels within main gui figure -----
        obj.CONTROL = uipanel('Parent',obj.H,'Title','CONTROL PANEL','FontSize',12,...
            'BackgroundColor','white','Units','Pixels','Position',[10 10 105*5+4 140]);
        obj.VIEW = uipanel('Parent',obj.H,'Title','VIEW','FontSize',12,...
            'BackgroundColor','white','Units','Pixels','Position',[10 160 105*5+4 455]);     
        % Populate control panel -----
        obj.gui.height = 105;
        obj.gui.width = 105;
        obj.h_splash = uicontrol('Parent',obj.CONTROL,'Style','togglebutton',...
            'BackgroundColor',[1 1 1],'Position',[(obj.gui.width*0) 1 obj.gui.width*5 obj.gui.height],...
            'Visible','on','CData',imread('splash.jpg'),'BusyAction','queue','Interruptible','off');
        pause(2)
        delete(obj.h_splash)
        obj.h_init = uicontrol('Parent',obj.CONTROL,'Style','togglebutton',...
            'BackgroundColor',[1 1 1],'Position',[(obj.gui.width*0) 1 obj.gui.width obj.gui.height],...
            'Callback',@obj.initPlayrec,'Visible','on','TooltipString','INITIALIZE playrec software',...
            'CData',imread('initGray.jpg'),'BusyAction','queue','Interruptible','on');
        obj.h_load = uicontrol('Parent',obj.CONTROL,'Style','togglebutton',...
            'BackgroundColor',[1 1 1],'Position',[(obj.gui.width*1) 1 obj.gui.width obj.gui.height],...
            'Callback',@obj.loadExperiment,'Visible','on','TooltipString','LOAD experiment file',...
            'CData',imread('loadGray.jpg'),'BusyAction','queue','Interruptible','on');
        obj.h_pause = uicontrol('Parent',obj.CONTROL,'Style','togglebutton',...
            'BackgroundColor',[1 1 1],'Position',[(obj.gui.width*2) 1 obj.gui.width obj.gui.height],...
            'Callback',@obj.pauseExperiment,'Visible','on','TooltipString','PAUSE experiment file',...
            'CData',imread('pauseGray.jpg'),'BusyAction','queue','Interruptible','on');
        obj.h_run = uicontrol('Parent',obj.CONTROL,'Style','togglebutton',...
            'BackgroundColor',[1 1 1],'Position',[(obj.gui.width*3) 1 obj.gui.width obj.gui.height],...
            'Callback',@obj.runExperiment,'Visible','on','TooltipString','RUN experiment or calibration file',...
            'CData',imread('runGray.jpg'),'BusyAction','queue','Interruptible','on');
        obj.h_abort = uicontrol('Parent',obj.CONTROL,'Style','togglebutton',...
            'BackgroundColor',[1 1 1],'Position',[(obj.gui.width*4) 1 obj.gui.width obj.gui.height],...
            'Callback',@obj.abortExperiment,'Visible','on','TooltipString','ABORT current process',...
            'CData',imread('abortGray.jpg'),'BusyAction','queue','Interruptible','on');
        obj.buttonManager(10)
    end    
    function buttonManager(varargin)
        obj = varargin{1};
        code = varargin{2};
        flickerLen = 0.1; % length of flicker for error notification
        flickerReps = 5; % number of flickers
        % 10s are for arlas gui
        % 20s are for initializing the system
        % 30s are for pausing 
        % 40s are for loading experiment files
        % 50s are for running
        % 60s are for aborting
        %
        % the 'Tag' field is used to indicate whether a button can be used
        % or not. Will be set to zero when its callback is currently
        % running, as well.
        switch code
            case 10 % initialize arlas gui (FUNCTION initGui)
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            
            case 20 % Begin initializing the system (FUNCTION initPlayrec)
                set(obj.h_init,'Value',1,'Tag','off','CData',imread('initGreen.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 21 % -- unsuccessful initialization
                for ii=1:flickerReps
                    set(obj.h_init,'Value',1,'Tag','off','CData',imread('initRed.jpg'))
                    pause(flickerLen)
                    set(obj.h_init,'Value',1,'Tag','off','CData',imread('initGreen.jpg'))
                    pause(flickerLen)
                end
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initGreen.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 22 % -- successful initialization
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
                
            case 30 % Begin pausing the system (FUNCTION pauseExperiment)
                set(obj.h_init,'Value',0,'Tag','off','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',1,'Tag','off','CData',imread('pauseGreen.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 31 % -- unsuccessful pause
                for ii=1:flickerReps
                    set(obj.h_pause,'Value',1,'Tag','off','CData',imread('pauseRed.jpg'))
                    pause(flickerLen)
                    set(obj.h_pause,'Value',1,'Tag','off','CData',imread('pauseGreen.jpg'))
                    pause(flickerLen)
                end
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','on','CData',imread('pauseYellow.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runGreen.jpg'))
                set(obj.h_abort,'Value',0,'Tag','on','CData',imread('abortRed.jpg'))
            case 32 % -- successful pause ON
                set(obj.h_init,'Value',0,'Tag','off','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','on','CData',imread('pauseGreen.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','on','CData',imread('abortRed.jpg'))
            case 33 % -- successful pause OFF
                set(obj.h_init,'Value',0,'Tag','off','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','on','CData',imread('pauseYellow.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runGreen.jpg'))
                set(obj.h_abort,'Value',0,'Tag','on','CData',imread('abortRed.jpg'))
                
            case 40 % Begin loading experiment file (FUNCTION loadExperiment)
                set(obj.h_init,'Value',0,'Tag','off','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',1,'Tag','off','CData',imread('loadGreen.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 41 % -- failed to load experiment file
                for ii=1:flickerReps
                    set(obj.h_load,'Value',1,'Tag','off','CData',imread('loadRed.jpg'))
                    pause(flickerLen)
                    set(obj.h_load,'Value',1,'Tag','off','CData',imread('loadGreen.jpg'))
                    pause(flickerLen)
                end
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 42 % -- successfully loaded experiment file
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadedYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runYellow.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            
            case 50 % Begin running an experiment file (FUNCTION runExperiment)
                set(obj.h_init,'Value',0,'Tag','off','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadedGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','on','CData',imread('pauseYellow.jpg'))
                set(obj.h_run,'Value',1,'Tag','off','CData',imread('runGreen.jpg'))
                set(obj.h_abort,'Value',0,'Tag','on','CData',imread('abortRed.jpg'))
            case 51 % -- unsuccessfully ran experiment
                for ii=1:flickerReps
                    set(obj.h_run,'Value',1,'Tag','off','CData',imread('runRed.jpg'))
                    pause(flickerLen)
                    set(obj.h_run,'Value',1,'Tag','off','CData',imread('runGreen.jpg'))
                    pause(flickerLen)
                end
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadedYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runYellow.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 52 % -- successfully ran experiment
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadedYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runYellow.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))

            case 60 % Begin aborting run (FUNCTION abortExperiment)
                set(obj.h_init,'Value',0,'Tag','off','CData',imread('initGray.jpg'))
                set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadedGray.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
                set(obj.h_abort,'Value',1,'Tag','off','CData',imread('abortRed.jpg'))
            case 61 % -- failed to abort run
                for ii=1:flickerReps
                    set(obj.h_abort,'Value',1,'Tag','off','CData',imread('abortGray.jpg'))
                    pause(flickerLen)
                    set(obj.h_abort,'Value',1,'Tag','off','CData',imread('abortRed.jpg'))
                    pause(flickerLen)
                end
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadedYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runYellow.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
            case 62 % -- successfully aborted run
                set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
                set(obj.h_load,'Value',0,'Tag','on','CData',imread('loadedYellow.jpg'))
                set(obj.h_pause,'Value',0,'Tag','off','CData',imread('pauseGray.jpg'))
                set(obj.h_run,'Value',0,'Tag','on','CData',imread('runYellow.jpg'))
                set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg')) 
            otherwise
        end
        pause(.05)
    end
    function buttonReset(varargin) % "hard reset" of buttons to initial state. In case something gets frozen
        obj = varargin{1};
        set(obj.h_init,'Value',0,'Tag','on','CData',imread('initYellow.jpg'))
        set(obj.h_pause,'Value',0,'Tag','off','CData',imread('calGray.jpg'))
        set(obj.h_load,'Value',0,'Tag','off','CData',imread('loadGray.jpg'))
        set(obj.h_run,'Value',0,'Tag','off','CData',imread('runGray.jpg'))
        set(obj.h_abort,'Value',0,'Tag','off','CData',imread('abortGray.jpg'))
    end
    
    % define the five main functions ------------------
    function initPlayrec(varargin) % initialize playrec
        obj = varargin{1};
        if strcmp(obj.h_init.Tag,'off')
            obj.h_init.Value = 0;
            return
        end
        try
            obj.objPlayrec.killPlots % if there are any open playrecARLas figures, make them disappear
        catch
        try
            delete(obj.objPlayrec) % delete any currently open playrecARLas objects
        catch
        end            
        end
        obj.buttonManager(20)
        set(obj.VIEW,'Title','VIEW: Initialize')
        try 
            obj.objInitARLas.killPlots
            delete(obj.objInitARLas);
        catch
        end
        try
            obj.objPlayrec.killPlots
        catch
        end
        obj.objInit = initARLas(obj); % instantiate an object of class initARLas
        obj.objInit.initGui % create the gui
        d = dir([obj.map.sysConfigs,'*.mat']); % look for previously saved initialization files
        if size(d,1) >= 1 % if files exist
            % ask user which one to use
            [fileName,pathName] = uigetfile([obj.map.sysConfigs,'*.mat'],'Select the initialization file.');
            if fileName == 0 % if user canceled and did not pick a file
                obj.buttonManager(21) % flash an error and discover new files
                obj.objInit.discover
                return
            end
            try % if previously saved initialization values exist, try to use them
                dummy = load([pathName,fileName]); % load the saved initialization
                obj.objInit.trySavedValues(dummy);
                obj.buttonManager(22)
            catch ME %-----------------------------------------------------
                errorTxt = {'  Issue: Unable to initialize: arlas.m using saved values, function init.playrec.'
                     '  Action:  Create new initialization.'
                     '  Location: arlas.initPlayrec.'
                    };
                errorMsgARLas(errorTxt);
                obj.buttonManager(21)
                obj.printError(ME)
            end
        else
            alertTxt = {'  Issue: No saved System Configuration Files wre detected.'
                 '  Action:  Discovering current system devices.'
                 '  Location: arlas.initPlayrec.'
                };
            alertMsgARLas(alertTxt);
            obj.buttonManager(21)
            obj.objInit.discover
            set(obj.VIEW,'Title','VIEW: ')
        end
    end
    function loadExperiment(varargin)
        obj = varargin{1};
        if strcmp(obj.h_load.Tag,'off')
            obj.h_load.Value = 0;
            return
        end
        try
            obj.objInit.killPlots
            %obj.objInit.makeInvisible % invisible the initialization gui
        catch
        end
        obj.buttonManager(40)
        set(obj.VIEW,'Title','VIEW: Load Experiment File')
        try % attempt to load an experiment file
            obj.expPathName = obj.map.experiments;
            obj.expFileName = uigetfile([obj.expPathName,obj.sep,'*.m'],'Load Experiment File');
            if obj.expFileName == 0 % if user canceled and did not pick a file
                obj.buttonManager(41) % flash an error and simply return
                set(obj.VIEW,'Title','VIEW: ')
                return
            else
                obj.expFileName = obj.expFileName(1:end-2); % strip off the .m extension
            end
            set(obj.VIEW,'Title','VIEW: ')
        catch ME
            set(obj.VIEW,'Title','VIEW: ')
            obj.expFileName = 0;
            obj.h_load.TooltipString = 'LOAD experiment file';
            obj.buttonManager(41)
            obj.printError(ME)
            return
        end
        if ~obj.expFileName  % if no experiment file was chosen or process was aborted
            obj.h_load.TooltipString = 'LOAD experiment file';
            obj.buttonManager(41)
        else % if an experiment file was chosen
            obj.h_load.TooltipString = ['LOADED EXPERIMENT: ',obj.expFileName];
            obj.buttonManager(42)
        end
    end
    function pauseExperiment(varargin) % pause the currently-running experiment
        obj = varargin{1};
        if strcmp(obj.h_pause.Tag,'off')
            obj.h_pause.Value = 0;
            return
        end
        obj.buttonManager(30) % starting pause routine...
        pause(0.001)
        try
            if obj.objPlayrec.pauseRun == 1 % if the run is already paused
                obj.buttonManager(33)
                pause(0.001)
                obj.objPlayrec.pauseRun = 0; % turn pause off
            else % if the run is not paused
                obj.buttonManager(32) % starting pause routine
                obj.objPlayrec.pauseRun = 1; % turn pause on
            end
        catch ME
            errorTxt = {'  Issue: Error pausing playrec.'
                 '  Action:  None.'
                 '  Location: arlas.pauseExperiment.'
                };
            errorMsgARLas(errorTxt);
            obj.printError(ME)
            obj.buttonManager(31)
            obj.objPlayrec.pauseRun = 0; % turn pause off
            return
        end
    end
    function runExperiment(varargin) % run the currently-loaded experiment
        obj = varargin{1};
        if strcmp(obj.h_run.Tag,'off')
            obj.h_run.Value = 0;
            return
        end
        try
            obj.objInit.killPlots
        catch
        end
        obj.buttonManager(50)
        set(obj.VIEW,'Title','VIEW: Playback & Record')
        obj.killRun = 0;
        try % get the subject, experiment, and operator IDs
            obj.getSubjID
            uiwait(obj.h_subjID) % wait until the figure is closed
        catch ME
            errorTxt = {'  Issue: Error getting subject ID.'
                 '  Action: None.'
                 '  Location: in arlas.runExperiment.'
                };
            errorMsgARLas(errorTxt);
            obj.buttonManager(51)
            obj.printError(ME)
            set(obj.VIEW,'Title','VIEW: ')
            return
        end
        if obj.subjID_OK == 0
            obj.buttonManager(51) % unsuccessful; possibly user closed box with upper right x
            set(obj.VIEW,'Title','VIEW: ')
            return
        end
        try % run the experiment
            try
                delete(obj.objPlayrec) % delete any currently open playrecARLas objects
            catch
            end
            try
                obj.objPlayrec = playrecARLas(obj.objInit); % initialize a new object of class playrecARLas
            catch ME
                errorTxt = {'  Issue: Error creating new playrecARLas object.'
                     '  Action: None.'
                     '  Location: in arlas.runExperiment.'
                    };
                errorMsgARLas(errorTxt);
                obj.buttonManager(51)
                obj.printError(ME)
                set(obj.VIEW,'Title','VIEW: ')
                return
            end
            feval(obj.expFileName,obj); % Here is where we run the experiment file ---------------
        catch ME
            if obj.objPlayrec.killRun == 1
                 errorTxt = {'  Issue: Run aborted by user.'
                     '  Action: Run stopped early.'
                     '  Location: in arlas.runExperiment.'
                    };
                errorMsgARLas(errorTxt);
                obj.buttonManager(51)
                obj.printError(ME)
                obj.objPlayrec.killPlots % get rid of playrecARLas plots
                obj.killRun = 1;
                return
            else
                errorTxt = {'  Issue: Error in experiment file.'
                     '  Action: Run stopped early.'
                     '  Location: in currently loaded experiment file.'
                     ['            ',obj.expFileName,'.m']
                    };
                errorMsgARLas(errorTxt);
                obj.buttonManager(51)
                obj.printError(ME)    
                obj.objPlayrec.killPlots % get rid of playrecARLas plots
                obj.killRun = 1;                
            end
            return
        end
        obj.buttonManager(52) % successful completion
        set(obj.VIEW,'Title','VIEW: ')
    end
    function abortExperiment(varargin) % abort the currently-running experiment
        obj = varargin{1};
        if strcmp(obj.h_abort.Tag,'off')
            obj.h_abort.Value = 0;
            return
        end
        obj.buttonManager(60)
        set(obj.VIEW,'Title','VIEW: Abort')
        try
            obj.objPlayrec.killRun = 1;
            obj.killRun = 1;
            pause(0.5)
            try
                playrec('delPage');
            catch
            end
        catch ME
             errorTxt = {'  Issue: Unsuccessful abort attempt.'
                 '  Action: Abort not completed.'
                 '  Location: in arlas.abortExperiment.'
                };
            errorMsgARLas(errorTxt);
            obj.buttonManager(61) % aborted unsuccesfully (with unexpected errors)
            obj.printError(ME)
            return
        end
        try
            obj.objPlayrec.killPlots
            %obj.objPlayrec.makeInvisible % if there are any open playrecARLas figures, make them disappear
        catch
        end
        obj.buttonManager(62) % aborted successfully
    end
    
    function getSubjID(varargin) % display dialog box for subject, experiment, and operator ID
        obj = varargin{1};
        try
            delete(obj.h_subjID)
        catch
        end
        obj.subjID_OK = 0; % reset to zero
        height = 105;
        width = 105;
        scrsz = get(0,'ScreenSize'); % get the current screen size
        left = round(scrsz(4) * .05);
        bottom = scrsz(4) * .1;        
        bottom = bottom + (1.4*105);
        rect = [left, bottom, width*5, height*2];
        obj.h_subjID = figure('Position',rect);
        set(obj.h_subjID,'Name',' ','NumberTitle','off','MenuBar','none','Resize','off','Color',[1 1 1])
        left = 290; width = 150; height = 40; bottom = 150; % SUBJECT ID
        obj.h_subjLabel = uicontrol('Style','text','String','Subject ID','FontSize',13,...
            'position',[left bottom width height],'parent',obj.h_subjID,'HandleVisibility','off',...
            'BackgroundColor',[1 1 1],'FontAngle','italic','HorizontalAlignment','left','Visible','on');
        left = 30; width = 250; height = 30; bottom = 162;
        obj.h_subjBox = uicontrol('Style','edit','String',obj.subjectID,'FontSize',13,...
            'position',[left bottom width height],'parent',obj.h_subjID,'HandleVisibility','off',...
            'BackgroundColor',[1 1 1],'Visible','on','HorizontalAlignment','left');
        left = 290; width = 150; height = 40; bottom = 110; % EXPERIMENT ID
        obj.h_expLabel = uicontrol('Style','text','String','Experiment ID','FontSize',13,...
            'position',[left bottom width height],'parent',obj.h_subjID,'HandleVisibility','off',...
            'BackgroundColor',[1 1 1],'FontAngle','italic','HorizontalAlignment','left','Visible','on');
        left = 30; width = 250; height = 30; bottom = 122;
        obj.h_expBox = uicontrol('Style','edit','String',obj.experimentID,'FontSize',13,...
            'position',[left bottom width height],'parent',obj.h_subjID,'HandleVisibility','off',...
            'BackgroundColor',[1 1 1],'Visible','on','HorizontalAlignment','left');
        left = 290; width = 150; height = 40; bottom = 70; % OPERATOR INITIALS
        obj.h_opLabel = uicontrol('Style','text','String','Operator Initials','FontSize',13,...
            'position',[left bottom width height],'parent',obj.h_subjID,'HandleVisibility','off',...
            'BackgroundColor',[1 1 1],'FontAngle','italic','HorizontalAlignment','left','Visible','on');
        left = 30; width = 125; height = 30; bottom = 82;
        obj.h_opBox = uicontrol('Style','edit','String',obj.operatorID,'FontSize',13,...
            'position',[left bottom width height],'parent',obj.h_subjID,'HandleVisibility','off',...
            'BackgroundColor',[1 1 1],'Visible','on','HorizontalAlignment','left');
        left = 385; width = 130; height = 50; bottom = 10;
        obj.h_enterSubjID = uicontrol('Style','pushbutton','BackgroundColor',[1 1 0],...
            'Position',[left bottom width height],'parent',obj.h_subjID,...
            'String','Enter ID','FontSize',13,'Visible','on','BusyAction','cancel',...
            'Interruptible','off','Callback',@obj.enterID);
        
    end

    function enterID(varargin) % get subject, experiment, and operator IDs and save them; create folders
        obj = varargin{1};
        subjID = get(obj.h_subjBox,'String'); % check subject ID is present
        if ~isempty(subjID)
            obj.subjectID = subjID;
        else
            uiwait(errordlg('Subject ID cannot be an empty string.','Subject ID Error','modal'))
            return
        end
        expID = get(obj.h_expBox,'String'); % check experiment ID is present
        if ~isempty(expID)
            d = dir(obj.map.data);
            N = length(d);
            match = 0;
            for ii=3:N % look to see if experiment folder already exists
                if d(ii).isdir
                    if strcmp(d(ii).name,expID)
                        match = 1;
                    end
                end
                if match == 1
                    break
                end
            end
            if match
                obj.experimentID = expID;
            else
                button = questdlg(['Experiment ID does not exist. Create new directory?'],...
                    'Create Experiment Directory','Yes','No','No');
                if strcmp(button,'No')
                    return
                else
                    success = mkdir(obj.map.data,expID);
                    if success
                        addpath([obj.map.data,expID])
                        obj.experimentID = expID;
                    else
                        error('Unable to create new Experiment Directory.')
                    end
                end
            end
            d = dir([obj.map.data,expID]);
            N = length(d);
            match = 0;
            for ii=3:N % look for existing subject ID
                if d(ii).isdir
                    if strcmp(d(ii).name,obj.subjectID)
                        match = 1;
                    end
                end
                if match == 1
                    break
                end
            end
            if ~match
                success = mkdir([obj.map.data,expID],obj.subjectID);
                pathName = [obj.map.data,expID,obj.sep,obj.subjectID];
                addpath(pathName)
                if ~success
                    error('Unable to create directory for subject ID.')
                end
            end
        else
            uiwait(errordlg('Experiment ID cannot be an empty string.','Experiment ID Error','modal'))
            return
        end
        opID = get(obj.h_opBox,'String');
        if ~isempty(opID)
           obj.operatorID = opID;
        else
            uiwait(errordlg('Operator Initials cannot be an empty string.','Operator ID Error','modal'))
            return
        end
        % if the ID input is all good, the following lines will execute
        obj.subjID_OK = 1;
        delete(obj.h_subjID)
    end    
    function printError(varargin)
        obj = varargin{1};
        ME = varargin{2};
        disp(ME.identifier)
        disp(ME.message)
        disp(ME.stack(1).line)            
    end
    
    % functions that get and return values for use in experiment files --------
    function [samplingRate] = fs(varargin) % return the current sampling rate
        obj = varargin{1};
        samplingRate = obj.objInit.fs_now;
    end
    function setRecList(varargin) % define the input channels to be used for recording
        % Usage: obj.setRecList(ch,label,micSens,gain); 
        % Specify channel number for each (1 through maxN, where maxN is the maximum for the sound card)
        %     For each, specify a label, mic sensitivity, and gain.
        %     Label is a string for idenfification and file saving purposes
        %     Mic sens is in V/Pa. If no microphone is used, set = 1.
        %     Gain refers to hardware gain applied prior to ADC by the sound card. Specify in dB.        
       obj = varargin{1};
       if size(varargin,2) ~= 5
            disp('Incorrect number of inputs')
            return
        end
        ch = varargin{2}; % channel designation
        ok = obj.checkInput_ch(ch);
        if ~ok
            return
        end
        label = varargin{3};
        micSens = varargin{4};
        ampGain = varargin{5};
        maxGain = 200; % maximum gain allowed. This added as a caution to avoid gain entered in linear units
        if ampGain > maxGain
          errorTxt = {'  Issue: Gain exceeds maxGain of 200 dB.'
                 '  Fix: Ensure gain is entered as a dB value, not as a linear value.'
                 '  Location: in playrecARLas.setRecList.'
                };
            errorMsgARLas(errorTxt);
            return
        end
        try
            indx = find(obj.objPlayrec.recChanList==ch); % check to see if chan already exists
            if isempty(indx)
               indx = length(obj.objPlayrec.recChanList) + 1;
            end
            obj.objPlayrec.recChanList(1,indx) = ch;
            obj.objPlayrec.micSens(1,indx) = micSens;
            obj.objPlayrec.ampGain(1,indx) = ampGain;
            obj.objPlayrec.label{1,indx} = label;
        catch
           errorTxt = {['  Issue: Error specifying stimulus: ',txt]
                 '  Action: None.'
                 '  Location: in playrecARLas.setRecList.'
                };
            errorMsgARLas(errorTxt);                         
        end        
    end
    function setPlayList(varargin) % define the output channels to be used for recording
        % Usage: obj.setPlayList(stimulus,ch);
        %  Load one vector at a time. Each vector is a channel of output.
        %      Use vector of zeros if desire an output channel with no output.
        %      Specify channel number for each (1 through maxN, where maxN is the maximum for the sound card)
        obj = varargin{1};
        if size(varargin,2) ~= 3
            disp('Incorrect number of inputs')
            return
        end
        ch = varargin{3}; % channel designation
        ok = obj.checkInput_ch(ch);
        if ~ok
            obj.objPlayrec.killRun = 1;
            obj.objPlayrec.killPlots
            return
        end
        stim = varargin{2}; % stimulus
        R = size(stim,1);
        if R < 2
            errorTxt = {'  Issue: Error specifying stimulus: number of rows must be > 1'
                 '  Action: None.'
                 '  Location: in playrecARLas.setPlayList.'
                };
            errorMsgARLas(errorTxt);
            return
        end
        try % if input is correct format, load for playback
            indx = find(obj.objPlayrec.playChanList==ch); % check to see if chan already exists
            if isempty(indx)
               indx = length(obj.objPlayrec.playChanList) + 1;
            end
            obj.objPlayrec.playChanList(1,indx) = ch;
            obj.objPlayrec.loadingDock.(matlab.lang.makeValidName(['Ch',num2str(ch)])) = stim;
        catch ME
            errorTxt = {['  Issue: Error specifying stimulus: ',txt]
                 '  Action: None.'
                 '  Location: in playrecARLas.setPlayList.'
                };
            errorMsgARLas(errorTxt);                        
        end
    end
    function clearRecList(varargin) % clear previously used input channels
        % Usage: obj.clearRecList(ch) --> this will delete a specific channel
        %        obj.clearRecList([3 2 5]) --> this will delete all channels specified in the vector
        %        obj(clearRecList    --> this will delete all channels (except ch0 default)
       obj = varargin{1};
       if size(varargin,2) == 1
           obj.objPlayrec.recChanList = 0;
           obj.objPlayrec.micSens = 1;
           obj.objPlayrec.ampGain = 0;
           n = length(obj.objPlayrec.label);
           for ii=n:-1:2
              obj.objPlayrec.label{1,ii} = []; 
           end
           counter = 1;
           for ii=1:length(obj.objPlayrec.label)
               if ~isempty(obj.objPlayrec.label{1,ii})
                   temp{1,counter} = obj.objPlayrec.label{1,ii};
                   counter = counter + 1;
               end
           end
           obj.objPlayrec.label = temp;
       elseif size(varargin,2) == 2
            try
                ch = varargin{2};
                for jj=1:length(ch)
                    ok = obj.checkInput_ch(ch(jj));
                    if ~ok
                        obj.objPlayrec.killRun = 1;
                        obj.objPlayrec.killPlots
                        return
                    end                                    
                    indx = find(obj.objPlayrec.recChanList==ch(jj)); % check to see if chan already exists
                    if ~isempty(indx)
                        obj.objPlayrec.recChanList(indx) = [];
                        obj.objPlayrec.micSens(indx) = [];
                        obj.objPlayrec.ampGain(indx) = [];
                        obj.objPlayrec.label{1,indx} = [];
                        counter = 1;
                        for ii=1:length(obj.objPlayrec.label)
                            if ~isempty(obj.objPlayrec.label{1,ii})
                                temp{1,counter} = obj.objPlayrec.label{1,jj};
                                counter = counter + 1;
                            end
                        end
                        obj.objPlayrec.label = temp;     
                    end
                end
            catch
               errorTxt = {'  Issue: Error deleting recording channel.'
                     '  Action: None.'
                     '  Location: in playrecARLas.clearRecList.'
                    };
                errorMsgARLas(errorTxt);                         
            end                   
       else
            disp('Incorrect number of inputs')
            return
       end
    end
    function clearPlayList(varargin) % clear previously used input channels
        % Usage: obj.clearPlayList(ch) --> this will delete a specific channel
        %        obj.clearPlayList([3 2 5]) --> this will delete all channels specified in the vector
        %        obj(clearPlayList    --> this will delete all channels (except ch0 default)
       obj = varargin{1};
       if size(varargin,2) == 1
           obj.objPlayrec.playChanList = 0;
           names = fieldnames(obj.objPlayrec.loadingDock);
           for ii=2:size(names,1)
               obj.objPlayrec.loadingDock = rmfield(obj.objPlayrec.loadingDock,names{ii});
           end
       elseif size(varargin,2) == 2
            try
                ch = varargin{2};
                for jj=1:length(ch)
                    ok = obj.checkInput_ch(ch(jj));
                    if ~ok
                        obj.objPlayrec.killRun = 1;
                        obj.objPlayrec.killPlots
                        return
                    end                                    
                    indx = find(obj.objPlayrec.playChanList==ch(jj)); % check to see if chan already exists
                    if ~isempty(indx)
                        obj.objPlayrec.playChanList(indx) = [];
                        name = ['Ch',num2str(ch(jj))];
                        obj.objPlayrec.loadingDock = rmfield(obj.objPlayrec.loadingDock,name);
                    end
                end
            catch
               errorTxt = {'  Issue: Error deleting recording channel.'
                     '  Action: None.'
                     '  Location: in playrecARLas.clearRecList.'
                    };
                errorMsgARLas(errorTxt);                         
            end                   
       else
            disp('Incorrect number of inputs')
            return
       end
    end
    function nReps(varargin) % set the number of playback/record repetitions
        obj = varargin{1};
        N = varargin{2};
        if N < 1
            error('number of repetitions mube be >= 1')
        end
        N = round(N); % force N to be an integer
        obj.objPlayrec = N;
    end
    function [header,data] = retrieveData(varargin) % return the header and recording matrix
        obj = varargin{1};
        partial = varargin{2};
        if ~isa(partial,'char')
            errorTxt = {'  Issue: Error specifying file to retrieve: input is not a string.'
                 '  Fix: Specify a valid partial or full file name, enclosed in quotes.'
                 '  Location: in playrecARLas.retrieveData.'
                };
            errorMsgARLas(errorTxt);            
            return
        end
        indx1 = strfind(obj.objPlayrec.savedFiles,partial);
        indx2 = find(~(cellfun('isempty',indx1)));
        if isempty(indx2)
            errorTxt = {'  Issue: Error specifying file to retrieve: no match.'
                 '  Fix: Specify a valid partial or full file name, enclosed in quotes.'
                 '  Location: in playrecARLas.retrieveData.'
                };
            errorMsgARLas(errorTxt);
            return            
        end
        if length(indx2) > 1
            errorTxt = {'  Issue: Error specifying file to retrieve: more than one match.'
                 '  Fix: Be more specific in giving a partial or full file name, enclosed in quotes.'
                 '  Location: in playrecARLas.retrieveData.'
                };
            errorMsgARLas(errorTxt);
            return                        
        end
        fileName = obj.objPlayrec.savedFiles{indx2}; % the name of the file saved to input channel 1
        pathName = obj.objPlayrec.savedFilesPath; % the location of the saved files
        dummy = load([pathName,fileName]); % dummy contains two fields: header and data
        header = dummy.header;
        data = dummy.data;
    end
    
    function [ok] = checkInput_ch(varargin) % check input arguments for the functions defineInput and defineOutput
        ok = 1;
        obj = varargin{1};
        ch = varargin{2};
        if ~isa(ch,'numeric')
            ok = 0;
            txt = 'Channel must be data type numeric.';
        end
        if mod(ch,1)~= 0
            ok = 0;
            txt = 'Channel must be an integer.';
        end
        if ch < 1
            ok = 0;
            txt = 'Channel must be >= 1.';
        end
        if ch > obj.objInit.chans_out
            ok = 0;
            txt = 'Channel must be <= to max number of initialized channels';
        end
        if ~ok
            errorTxt = {['  Issue: Error specifying channel: ',txt]
                 '  Action: None.'
                 '  Location: in playrecARLas.checkInput_ch.'
                };
            errorMsgARLas(errorTxt);
        end
    end
    function [ok] = checkForErrors(varargin) % check to see if experiment should continue or stop due to errors
         obj = varargin{1};
        ok = ~obj.objPlayrec.killRun;
    end
end
end

