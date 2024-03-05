function julia_main()::Cint
    using Genie
    Genie.loadapp("./")

    wait()

    return 0 # if things finished successfully
end