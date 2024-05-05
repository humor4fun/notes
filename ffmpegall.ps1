# if it fails to run, unblock scripts using an admin shell and execute the following:
# Set-ExecutionPolicy RemoteSigned
$author = "Chris Holt"
$title = "ffmpegall.ps1"
$version_history = "v1.0 - February 8, 2024", "v1.1 - May 4, 2024"
$host.ui.RawUI.WindowTitle = "ffmpegall.ps1: Setup"

if ($args[0] -eq "-h" -Or $args[0] -eq "--h" -Or $args[0] -eq "--help" -Or $args[0] -eq "-help"){
	Write-Host "
	Author: $author
	Title: $title
	Version History:
	$version_history
	
	Description:
		Process all files in the designated '$inbox' folder (recursively) with the hardcoded ffmpeg map settings. Converted files are stored in the '$donebox'. Upon completion, the file being processed is moved from the '$inbox' to the '$outbox'. If an error occurs during processing the script will halt and request to delete the failed file, then exit and need to be restarted.
		
		WARNING: Executing this script will clear your error buffer.
		NOTE: For non-ffmpeg-able files, this script will simply move them without triggering an error state.
		
	The Default ffmpeg map:
		ffmpeg -i infile -map 0:v -map 0:m:language:eng -c:v hevc -c:a copy -c:s copy donefile 
			-i infile				Set the input file (from the script variable)
			-map 0:v				Get all the video streams and select them for processing
			-map 0:m:language:eng	Select only the ENGLISH audio and subtitle streams for processing
			-c:v hevc				Set the output codec to HEVC (h.265); this may trigger transcoding
			-c:a copy				Set the audio codec to copy (do not transcode)
			-c:s copy				Set the subtitle codec to copy (do not transcode)
			donefile				Set the file name for the output file (from the script variable)
		To use this for selecting a different audio/sub language, change the map language that is hardcoded.
	
	Usage:
		./ffmpegall.ps1 [-h, --h, -help, --help]
			Display this help message
			
		./ffmpegall.ps1 [-w, --w, -wizard, --wizard]
			Run the script using the input wizard to prompt user for all inputs.
			
		./ffmpegall.ps1 [codec] inbox outbox donebox [log]
			codec		(optional) The ffmpec codec for re-encoding the video file. Defaults to hevc if not provided.
			inbox		The folder to where video files are located to be processed.
			outbox		The folder to move the video files to after processing.
			donebox		The folder to save the converted files to when processing.
			log			(optional) the file where log data should be written
			cleanup		(optional) can be set to 'delete' to remove source files after processing; Defaults to 'move' if not provided.
			
			Note: script can only be run with all optional parameters or with no optional parameters (but not some optional parameters).
			
	Encoder Notes:
		To use nvidia GPU hardware accelleration, the following must be installed.
			1. Visual Studio (https://visualstudio.microsoft.com/free-developer-offers/)
			2. CUDA SDK (https://developer.nvidia.com/cuda-downloads)
			3a. Compile ffmpeg on the target host (https://github.com/m-ab-s/media-autobuild_suite?tab=readme-ov-file)
			3b. See also: https://docs.nvidia.com/video-technologies/video-codec-sdk/12.0/ffmpeg-with-nvidia-gpu/index.html
		With Intel ARC A770 (others not tested)
			* Using the basic Intel graphics drivers results in 50% or lower performance when running hevc_qsv as the encoder on an A770 versus the iGPU in an i7-6700k. This is strange, but might be related to the resiable-bar featues not being enabled at time of testing.
		Intel iGPU
			* integrated GPU can perform hevc_qsv (or other QuickSyncVideo) codecs decently well on any processor that supports it. Performance was about 25%-50% of the MSI GTX 1070 8gb card that was teste.
			
	Future:
		Set the language selection as an input variable (also allow it to be non-deleting)
		Change the inbox processing to be able to handle subfolders
		change inbox processing to delete all non-video files and then only process the videos.
		Figure out how to use flags to specify parameters
		Figure out how to have the script detect graphics cards and automatically switch from defauly hevc libraries to the dedicated hevc (hevc_nvenc or hevc_qsv) or other  h.264, vp1, etc codec libraries.
		Bug: The Destination file size always reports a 0. I've tried Get-Item.Length, Get-ChildItem.Length, and Get-ItemProperty but they all report 0
		
	ffmpeg Errors:
	---
	 [matroska @ 000002078f0ebf00] Only audio, video, and subtitles are supported for Matroska.
	[out#0/matroska @ 000002078ea581c0] Could not write header (incorrect codec parameters ?): Invalid argument
	[vf#0:0 @ 000002078ea58cc0] Error sending frames to consumers: Invalid argument
	[vf#0:0 @ 000002078ea58cc0] Task finished with error code: -22 (Invalid argument)
	[vf#0:0 @ 000002078ea58cc0] Terminating thread with return code -22 (Invalid argument)
	[out#0/matroska @ 000002078ea581c0] Nothing was written into output file, because at least one of its streams received no packets.
	--- --> To resolve this error -TEMPORARILY- add '-dn' as a flag to the ffmpeg command line when running this script. You'll know its needed if you have a file that processes OK, but results in a 0kb output file. The command line should show the above errors from ffmpeg talking about some errors in one or more streams.
	"
	
	exit
}

if ($args[0] -eq "-w" -Or $args[0] -eq "--w" -Or $args[0] -eq "--wizard" -Or $args[0] -eq "-wizard"){
	Read-Host "ffmpeg Codec (must be installed/built for ffmpeg)" $codec
	Read-Host "Inbox folder (files that need to be converted)" $inbox
	Read-Host "Outbox folder (where to move the files after processing from the inbox)" $outbox
	Read-Host "Donebox folder (where to write the converted files)" $donebox
	Read-Host "Logfile (where to write the processing log data)" $log
	Read-Host "Delete or Move files after processing? (delete, move)" $cleanup
	
}elseif ($args.Count -eq 3){
	$codec = "hevc"
	$inbox = $args[0]
	$outbox = $args[1]
	$donebox = $args[2]
	$log = "ffmpegall.log"
	$cleanup = "move"
	
}elseif ($args.Count -eq 5){
	$codec = $args[0]
	$inbox = $args[1]
	$outbox = $args[2]
	$donebox = $args[3]
	$log = $args[4]
	$cleanup = $args[5]
	
}else {
	$codec = "hevc"
	$inbox = "E:\ffmpegall\inbox"
	$outbox = "E:\ffmpegall\outbox"
	$donebox = "E:\ffmpegall\donebox"
	$log = "ffmpegall.log"
	$cleanup = "move"
}

#clear the error buffer
$error.clear()

#get all files in the inbox folder
$files = Get-ChildItem $inbox

#write a log of all the parameters
Add-Content -Path $log -Value ""
Add-Content -Path $log -Value "ffmpegall.ps1 Version: $version"
Add-Content -Path $log -Value "$(Get-Date) Start (script): ./ffmpegall.ps1 $codec $inbox $outbox $donebox $log"

#variabilaes for benchmarking
$sizesourcetotal = 0
$sizedestinationtotal = 0
$timeffmpegtotal = 0
$timemovetotal = 0
$timeremovetotal = 0

foreach ($f in $files){
	$host.ui.RawUI.WindowTitle = "ffmpegall: Setup: $f"
	Add-Content -Path $log -Value "$(Get-Date) Start (file): $f"
    Write-Host "....++++.... Starting $infile ....++++.... "
	
	$infile = "$inbox\$($f.Name)"
	$outfile =  "$outbox\$($f.Name)"
    $donefile = "$donebox\$($f.BaseName)[HEVC-out].mkv"
	
	#get file size for benchmarking
	$sizesource = (Get-ChildItem -Path $infile).Length
	$sizesourcetotal += $sizesource
	
	Write-Host "	+++++		
	New item found: $infile
	+++++"
	Write-Host "		inbox: $inbox"
	Write-Host "		outbox: $outbox"
	Write-Host "		donebox: $donebox"
	Write-Host "		log: $log"
	Write-Host "		file: $f"
	Write-Host "		infile: $infile"
	Write-Host "		outfile: $outfile"
	Write-Host "		donefile: $donefile"
	Write-Host "		cleanup: $cleanup"
	
	$host.ui.RawUI.WindowTitle = "ffmpegall: ffmpeg: $f"
	#######
	#ffmpeg process each file in the inbox
	#######
		#log, measure/do, log
		Add-Content -Path $log -Value "$(Get-Date) Start (ffmpeg): ffmpeg -i $infile -map 0:v -map 0:m:language:eng -c:v $codec -c:a copy -c:s copy $donefile"
		$ffmpegtime = Measure-Command {ffmpeg -i $infile -map 0:v -map 0:m:language:eng -dn -c:v $codec -c:a copy -c:s copy $donefile}
		Add-Content -Path $log -Value "$(Get-Date) End (ffmpeg)"
		$timeffmpegtotal += $ffmpegtime.TotalSeconds
		
		#get file size for benchmarking
		#need to get the new item ebefore measuring it?
		$sizedestination = Get-ItemProperty -Path $donefile | Select-Object -ExpandProperty Length
		$sizedestinationtotal += $sizedestination
		Add-Content -Path $log -Value "$(Get-Date) Measurement (files): Source- $($sizesource/1GB)GB -> Destination- $($sizedestination/1GB)GB"
		
		if($sizedestination -eq 0){
			#BUG HERE -- These are for debugging but I haven't solved this bug. Best I can do is log the attempts
			Add-Content -Path $log -Value "$(Get-Date)   Bug: Destination file size is not correct Get-Item.Length :: $(((Get-Item -Path $donefile).Length)/1GB) GB"
			Add-Content -Path $log -Value "$(Get-Date)   Bug: Destination file size is not correct Get-ChildItem.Length :: $(((Get-ChildItem -Path $donefile).Length)/1GB) GB"
			Add-Content -Path $log -Value "$(Get-Date)   Bug: Destination file size is not correct Get-Item.Length :: $((Get-ItemProperty -Path $donefile | Select-Object -ExpandProperty Length)/1GB) GB" 
		}
		
		#log/print measurement
		Add-Content -Path $log -Value "$(Get-Date) Duration (ffmpeg): $([timespan]::fromseconds($ffmpegtime.TotalSeconds).ToString("hh\:mm\:ss\,fff"))"	
		Write-Host "TotalSeconds: $($ffmpegtime.TotalSeconds) seconds"
		
		#check for error and die if something went wrong
		if($Error -ne ""){
			Write-Host "		============================
			============================
			============================
			============================
				!!!ffmpeg error!!!
			============================
			============================
			============================
			============================"
			#delete the broken file if ffmpeg had an error
			Remove-Item $donefile
			
			#log the deleted file and the error, then die
			Add-Content -Path $log -Value "$(Get-Date) Delete-Item (ffmpeg): $donefile"
			Add-Content -Path $log -Value "$(Get-Date) EXIT WITH ERROR (ffmpeg): $Error"
			exit
		}
	#######
	#/end of ffmpeg processing
	#######
	
	$host.ui.RawUI.WindowTitle = "ffmpegall: Cleanup: $f"
	#######
	#move the source item to the outbox so it doesn't get re-processed somehow
	#######
		if($cleanup -eq "move" -Or $cleanup -eq "delete"){
			#log, measure/do, log
			Add-Content -Path $log -Value "$(Get-Date) Start (Move-Item): Source- $infile Destination- $outfile"
			$movetime = Measure-Command{Move-Item -Path $infile -Destination $outfile}
			Add-Content -Path $log -Value "$(Get-Date) End (Move-Item)"
			$timemovetotal += $movetime.TotalSeconds
			
			#log/write the measurement
			Add-Content -Path $log -Value "$(Get-Date) Duration (Move-Item): $([timespan]::fromseconds($movetime.TotalSeconds).ToString("hh\:mm\:ss\,fff"))"
			Write-Host "TotalSeconds: $($movetime.TotalSeconds) seconds"
			
			#check for error and die if something went wrong
			if($Error -ne ""){
				Write-Host "		============================
				============================
				============================
				============================
					!!!Move-Item error!!!
				============================
				============================
				============================
				============================"
				
				#log the error and die
				Add-Content -Path $log -Value "$(Get-Date) EXIT WITH ERROR (Move-Item): $Error"
				exit
			}
		}else{
			Add-Content -Path $log -Value "$(Get-Date) Error (Move-Item): Cleanup variable not set properly, should be 'move' or 'delete' but was '$cleanup'.)"
		}
	#######
	#/end of move
	#######
	
	#######
	#delete the source item to make sure there is disk space
	#######
		if($cleanup -eq "delete"){
			#log, do/measure, log
			Add-Content -Path $log -Value "$(Get-Date) Start (Remove-Item): $outfile"
			$removetime = Measure-Command {Remove-Item -Path $outfile}
			Add-Content -Path $log -Value "$(Get-Date) End (Remove-Item): $outfile"
			$timeremovetotal += $removetime.TotalSeconds
			
			#log/print measurement
			Add-Content -Path $log -Value "$(Get-Date) Duration (Remove-Item): $([timespan]::fromseconds($removetime.TotalSeconds).ToString("hh\:mm\:ss\,fff"))"
			Write-Host "TotalSeconds: $($removetime.TotalSeconds) seconds"
			
			#check if an error occured and die
			if($Error -ne ""){
				Write-Host "		============================
				============================
				============================
				============================
					!!!Remove-Item error!!!
				============================
				============================
				============================
				============================"
				Add-Content -Path $log -Value "$(Get-Date) EXIT WITH ERROR (Remove-Item): $outfile"
				exit
			}
			
			Write-Host "....++++.... Done processing $infile ....++++.... 
			"
		}
	#######
	#/end of delete
	#######
	
	Add-Content -Path $log -Value "$(Get-Date) End (file): $f"
}

$host.ui.RawUI.WindowTitle = "ffmpegall: Final Logging"
Add-Content -Path $log -Value "$(Get-Date) End (script)"
Write-Host "....++++.... Completed successfully! ....++++.... "
Add-Content -Path $log -Value "$(Get-Date) Finished processing."
Add-Content -Path $log -Value "$(Get-Date) Processed $($files.Count) files."
Add-Content -Path $log -Value "$(Get-Date) Input Size: $($sizesourcetotal/1GB)GB"
Add-Content -Path $log -Value "$(Get-Date) Output Size: $($sizedestinationtotal/1GB)GB"
Add-Content -Path $log -Value "$(Get-Date) Data Saved: $(($sizesourcetotal - $sizedestinationtotal)/1GB)GB"
Add-Content -Path $log -Value "$(Get-Date) ffmpeg Time: $([timespan]::fromseconds($timeffmpegtotal).ToString("hh\:mm\:ss\,fff"))"
Add-Content -Path $log -Value "$(Get-Date) Move-Item Time: $([timespan]::fromseconds($timemovetotal).ToString("hh\:mm\:ss\,fff"))"
Add-Content -Path $log -Value "$(Get-Date) Remove-Item Time: $([timespan]::fromseconds($timeremovetotal).ToString("hh\:mm\:ss\,fff"))"
Add-Content -Path $log -Value "$(Get-Date) Total Time: $([timespan]::fromseconds($timeremovetotal + $timemovetotal + $timeffmpegtotal).ToString("hh\:mm\:ss\,fff"))"
Add-Content -Path $log -Value "$(Get-Date) Completed Successfully!"

