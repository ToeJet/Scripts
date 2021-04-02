ZoomUpdate

Simple script to download the latest version of Zoom  and install on a Fedora machine.

Checks for a new version from Zoom site.  If it finds it,  it downloads to a unique name,  terminates any running zoom client.  Then installs the new file.  I leave my linux machine always running.   If zoom is not running at the start of the day,  just launch as normal, it will be the latest version.

james@toebesacademy.com
https://james.toebesacademy.com
Let me know what you think.

Installation:
1. Create a subfolder under the root home folder then place ZoomUpdate.sh there.  You can use another folder, just update the paths.
2. Schedule as a Cron job with logging.  The following entry runs every night at 5 after midnight.
    5 0 * * *  /root/ZoomUpdate/ZoomUpdate.sh 2>&1 >>/root/ZoomUpdate/ZoomUpdate.log
3. All versions are downloaded to the same folder as the script.   Filename is changed to match datestamp.
4. Periodically review log to see update history

