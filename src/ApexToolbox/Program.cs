using ApexToolbox;

if (args.Length == 3 && args[0] == "--run-script")
    return ScriptRunner.RunElevatedWorker(args[1], args[2]);

ApplicationConfiguration.Initialize();
Application.Run(new MainForm());
return 0;