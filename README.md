# Steam-Debloat

# Well starting the github I want to thank Optijuegos and TiberiumFusion for making this project possible. If something happens with a license or copyright I will talk about it <3

# WARNING
THIS IS A WINDOWS 7 INSTALLATION ON WINDOWS
8.1/10/11 STEAM, SO IT IS A NEW STEAM WITHOUT THE GAMES OR SETTINGS MADE ALSO KNOW THAT GAMES LIKE CSGO CANNOT BE PLAYED SINCE THE LATEST VERSION OF STEAM IS REQUIRED IF OR IF (POSIBLY ALL VALVE GAMES WITH ITS VAC, less left 4 dead 2 (top game) that works

### Features:

- An older version of Steam is used that consumes less system resources.
- Many things are disabled to optimize resource consumption.

### TiberiumFusion <3
<p></p>
Github: https://github.com/TiberiumFusion

#### If you are antisocial and have no friends either in life or on steam I made you a custom bat file <3
#### Ignore this guide and download your steam for antisocial in release

### 1+ Well starting the github the first thing to do is just download the bat file/batch file in release.

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/13313e98-ada6-4f55-8d78-3cbe25cb39f2)

### 2+ The bat is automatic so you won't have to do anything until the end.

### 3+ Look in the task manager ctrl+shift+esc in the background if there are no steam processes running

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/7459981b-0a94-4e0a-804a-ed47fd7ff352)
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/e4e72e6e-0673-4194-b8ef-12cbacbdf1cc)

### 4+ After it will be FixedSteamFriendsUI Quick Patcher.exe

### Press the patch Install FriendUI Patch and wait for it to appear that it has been patched.
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/90d55cae-556d-4101-ba45-bb3fd56c74e6)
<p></p>

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/af15e452-cd63-45f7-aa39-a5bca465d8ad)

### 5+ Log in because it is a steam in another location than the default one

###  6+ After logging in and Steam has started, you can check if the friends list works, if it works, go to the next step 7+.

### 6.5+ If it doesn't work for you, keep reading, close Steam from the taskbar and wait for the processes to close (also the Tiberium program will tell you that Steam is still in the background) just patch it again and open Steam if, due to strange cases, it still doesn't work. The friends list works, patch it with version 2.0.2 and if for no rational reason it still works, patch it with 1.2.0 and if it still doesn't work, redo all the steps

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/ec24376a-47b6-4a15-aecd-8b9e2f362423)

### 7+ This step is only to further optimize steam
##### Copy and paste if you are interested in my configuration

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/5e67f706-4836-4f14-81d1-b1f3fc6914a7)
<p>

</p>

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/53c4a824-c4df-442f-805f-502639d790f7)
<p>
  </p>
 
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/957d8f8b-6486-4394-8eaa-b035d608045a)
<p>
  </p>
  
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/8405bc8e-9876-4db4-aaf9-d8966485c04c)
<p>
  </p>
  
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/edb76bc4-a5b8-4ec8-89b6-0fef918910e4)
<p>
  </p>
  
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/f07c2c50-457f-485c-9ef6-1c78b01c10a1)
<p>
  </p>
  
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/9829ecea-654c-4161-9378-ad1fdbebc8c8)
<p>
  </p>
  
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/7c445cfa-44b7-4ea0-85d4-76b9f24a31b5)
<p>
  </p>
  
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/2056157a-d341-425b-a5cc-90375f9e0d1e)
<p>
</p>

## Some things could disable common things you use so I recommend testing

> Results
### 150-180 mb average

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/b8578355-a070-4e5a-8830-aed70ab6aecb)
> Results for antisocial (many functions are disabled) 
### 30-50 mb average

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/6202931d-b31d-4c97-84c8-fa16bed9a06a)

##### Why does this happen? Because ` -cef-force-32bit` was added to the launch parameters, which disables ` steamwebhelper` startup, which is used for the friends window (I think the workshop does not work without webhelper), among other things, it disables having it.
