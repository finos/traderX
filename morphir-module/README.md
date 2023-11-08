edit build.gradle tasks to contain file location of morphir command

In your command prompt type: 
```
> where morphir-elm
```
and copy the file path ending with cmd
*Example* 
```
> where morphir-elm
C:\Users\user.name\AppData\Roaming\npm\morphir-elm.cmd

```

replace with copied file path in build.gradle
```
task compileElm(type: Exec) {
commandLine 'YOUR morphir-elm command location', 'make'
}

task generateScala(type: Exec) {
commandLine 'YOUR morphir-elm command location', 'gen'
}
```

