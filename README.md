# Steam-Debloat

# Well starting the github I want to thank TiberiumFusion for making this project possible. If something happens about copyright I will talk about it <3

# WARNING
YOU CANNOT PLAY GAMES LIKE CSGO OR CSGO 2 SINCE THE LATEST VERSION OF STEAM IS REQUIRED YES OR YES (POSIBLY ALL VALVE GAMES WITH ITS VAC, try left 4 dead 2 and it works (top game)

### Characteristics:

- An old version of Steam is used that consumes less system resources by not having so many new things.
- Many things are disabled to optimize resource consumption.

### Tiberium Fusion <3
<p></p>
Github: https://github.com/TiberiumFusion

#### If you are antisocial and have no friends in life or on Steam, click here to download your personalized Steam <3.
[link](https://github.com/mtytyx/Steam-Debloat/releases/download/release-fix/Steam.for.Antisocials.bat)

<p></p>

### 1+ Well, starting with this guide, the first thing you should do is download the bat file here if you are a person WITH FRIENDS.
[link](https://github.com/mtytyx/Steam-Debloat/releases/download/release-fix/Steam-Github.bat)
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/13313e98-ada6-4f55-8d78-3cbe25cb39f2)

### 2+ The bat is automatic so you won't have to do anything until the end.

### 3+ Then FixSteamFriendsUI Quick Patcher.exe will open.

### Press the button below to patch Steam FriendUI and wait for it to appear that it has been patched.
![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/90d55cae-556d-4101-ba45-bb3fd56c74e6)
<p></p>

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/af15e452-cd63-45f7-aa39-a5bca465d8ad)
<p></p>

### 3.5+ If for some reason the patch button does not appear, close FixSteamFriendsUI Quick Patcher.exe.
<p></p>

![image](https://github.com/mtytyx/Steam-Debloat/assets/168254237/51119fcc-e3a4-4d0a-8cf8-d24c1d74c64e)
### Press win+r and type cmd
![image](https://github.com/mtytyx/Steam-Debloat/assets/168254237/4313e158-a188-442d-a3e2-7b3bf812039b)
![image](https://github.com/mtytyx/Steam-Debloat/assets/168254237/f1b092c9-adfe-42d9-808c-e365ab1b1a48)

### Copy and paste this into cmd
> start "" "%temp%\QuickPatcher_Patch_v3.0.0+\FixedSteamFriendsUI QuickPatcher.exe"
<p></p>
##### And press the patch button again. If it still doesn't work, patch again in a while and go directly to point 3.5+ of this guide.
<p></p>

### 4+ After Steam has started, you can check if the friends list is working. If it doesn't work go to step 3.5+.

### 5+ This step is only to further optimize the vapor.
##### Copy and paste if you are interested in my setup.

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

## Some things can disable common things you use, so I recommend trying it

> Results
### 130-180mb average

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/b8578355-a070-4e5a-8830-aed70ab6aecb)
> Results for antisocial (many features are disabled)
### Average 30-50 MB

![image](https://github.com/mtytyx/Steam-Debloat-/assets/168254237/6202931d-b31d-4c97-84c8-fa16bed9a06a)

##### Why did this happened? Because `-cef-force-32bit` was added to the startup parameters, which disables the launch of `steamwebhelper`, which is used for the friends window (I think Workshop doesn't work without webhelper), among other things , disable having it.
