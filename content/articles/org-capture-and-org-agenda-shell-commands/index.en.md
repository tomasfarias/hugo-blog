+++
title = "Org-capture and Org-agenda from anywhere in Linux"
author = ["Tomás Farías Santana"]
date = 2024-10-03T00:00:00+02:00
draft = false
+++

I use [Org](https://orgmode.org/) for capturing TODO items in an `inbox.org` file that gets read and displayed in my Org agenda views. A pretty standard workflow, at least for your average Emacs/Org user. However, every time I am not in my Emacs workspace I feel slightly annoyed with the added friction of having to either open a new frame or switch to my Emacs workspace in order to run `org-capture` or `org-agenda`. I wish Emacs functions could be called as shell commands that I can bind or add to my launcher.

Luckily for me, they can: With the only prerequisite being that [Emacs is running as a daemon](https://www.gnu.org/software/emacs/manual/html_node/emacs/Emacs-Server.html), we can use `emacsclient` to evaluate any ELisp expression, including calling `org-capture` and `org-agenda`. I got this idea from [this Mac owner's Club blog post](https://macowners.club/posts/org-capture-from-everywhere-macos/): The author opened my eyes to this new "Emacs functions as shell commands" world that I partially knew it had to exist, but I was missing that last push to reach the light at the end of the tunnel.

Here, I will show you how I have set up my own ELisp functions to run on Linux to achieve access to `org-capture` and `org-agenda` from anywhere[^fn:1].


## Show me the ELisp {#show-me-the-elisp}

Enough introduction, let's jump right in. First, this is the ELisp function I use to invoke `org-capture`:

```emacs-lisp { linenos=true, linenostart=1 }
(defcustom tomas/org-capture-frame-name "**Capture**"
  "Customize dedicated frame name to launch `org-capture' in."
  :type 'string)

(defun tomas/org-capture-frame (template)
  "Invoke `org-capture' in a dedicated Emacs frame.

     This function is designed to be called from a shell script using `emacsclient'.
     If the dedicated frame already exists, we will use it, otherwise we will create a
     new frame.

     Finally, the dedicated frame will be deleted up after `org-capture' finalizes."
  (interactive '(nil))

  (if (not (equal tomas/org-capture-frame-name (frame-parameter nil 'name)))
      (make-frame '((name . tomas/org-capture-frame-name))))

  (select-frame-by-name tomas/org-capture-frame-name)
  (delete-other-windows)

  (defun org-capture-after-finalize-clean-up ()
    "Clean up after `org-capture' finalizes.

    We delete the dedicated frame and removing advice."
    (advice-remove 'org-capture-place-template 'delete-other-windows)
    (remove-hook 'org-capture-after-finalize-hook 'org-capture-after-finalize-clean-up)

    (select-frame-by-name tomas/org-capture-frame-name)
    (delete-frame nil t))

  (add-hook 'org-capture-after-finalize-hook 'org-capture-after-finalize-clean-up)
  (advice-add #'org-capture-place-template :after 'delete-other-windows)

  (org-capture nil template))
```

A few things to note in this function:

1.  The dedicated frame where we will be calling `org-capture` is identified by its name, by default `"***Capture***"`. This can be customized.
2.  I take a `template` argument as I will setup multiple [actions in a desktop entry](https://specifications.freedesktop.org/desktop-entry-spec/latest/extra-actions.html) to access each of my `org-capture` templates.
3.  There is some adding and removing of a hook and function advice necessary to have `org-capture` occupy the entire frame. This partially works, but a more fluent Emacs user may find a better way to achieve the same result. Moreover, as I will show you later, it doesn't quite work if not passing a `template`.

Similarly, here is the ELisp function used to invoke `org-agenda`:

```emacs-lisp { linenos=true, linenostart=1 }
(defcustom tomas/org-agenda-frame-name "**Agenda**"
  "Customize dedicated frame name to launch `org-agenda' in."
  :type 'string)

(defun tomas/org-agenda-frame (command)
  "Invoke `org-agenda' in a dedicated Emacs frame.

   This function is designed to be called from a shell script using `emacsclient'.
   If the dedicated frame already exists, we will use it, otherwise we will create a
   new frame.

   Finally, the dedicated frame will be deleted up after `org-agenda' finalizes."
  (interactive '(nil))

  (if (not (equal tomas/org-agenda-frame-name (frame-parameter nil 'name)))
      (make-frame '((name . tomas/org-agenda-frame-name))))

  (select-frame-by-name tomas/org-agenda-frame-name)
  (delete-other-windows)

  (defun org-agenda-quit--clean-up ()
    "Close the frame after `org-agenda-quit'."
    (advice-remove 'org-agenda 'delete-other-windows)
    (advice-remove 'org-agenda-quit 'org-agenda-quit--clean-up)
    (advice-remove 'org-agenda-Quit 'org-agenda-quit--clean-up)

    (select-frame-by-name tomas/org-agenda-frame-name)
    (delete-frame nil t))

  (advice-add 'org-agenda-quit :after #'org-agenda-quit--clean-up)
  (advice-add 'org-agenda-Quit :after #'org-agenda-quit--clean-up)
  (advice-add 'org-agenda :after #'delete-other-windows)

  (org-agenda nil command))
```

Again, a few of things to note here:

1.  The dedicated frame where we will be calling `org-agenda` is identified by its name, by default `"***Agenda***"`. This can be customized.
2.  Similar to `template` before, we now pass a `command` argument to select the desired `org-agenda` view.
3.  The clean-up code, which is very similar in objectives and limitations as the previous function, is tied up to quitting the agenda as there is nothing finalizing here.


## Emacs functions as desktop entries {#emacs-functions-as-desktop-entries}

With the functions loaded, we can now add [desktop entries](https://specifications.freedesktop.org/desktop-entry-spec/latest/) to call them via `emacsclient`. Note that, as stated at the beginning, using `emacsclient` will require Emacs to be running as a daemon.

Here is the desktop entry for `org-capture`:

```cfg { linenos=true, linenostart=1 }
[Desktop Entry]
Name=Capture
Comment=Capture in org-mode using a separate Emacs frame
Exec=/usr/bin/emacsclient -c -e '(tomas/org-capture-frame nil)' -F '((name . "**Capture**"))'
Icon=emacs
Type=Application
Terminal=false
Categories=TextEditor;
Actions=inbox;

[Desktop Action inbox]
Name=Inbox
Exec=/usr/bin/emacsclient -c -e '(tomas/org-capture-frame "i")' -F '((name . "**Capture**"))'

[Desktop Action inbox]
Name=Work Inbox
Exec=/usr/bin/emacsclient -c -e '(tomas/org-capture-frame "wi")' -F '((name . "**Capture**"))'
```

Note that we have defined two actions: one for each template. My application launcher will display multiple options for "Capture": one for each capture template.

And similarly, here is the desktop entry for `org-agenda`:

```cfg { linenos=true, linenostart=1 }
[Desktop Entry]
Name=Agenda
Comment=Agenda in org-mode using a separate Emacs frame
Exec=/usr/bin/emacsclient -c -e '(tomas/org-agenda-frame nil)' -F '((name . "**Agenda**"))'
Icon=emacs
Type=Application
Terminal=false
Categories=TextEditor;
Actions=inbox;

[Desktop Action inbox]
Name=All
Exec=/usr/bin/emacsclient -c -e '(tomas/org-agenda-frame "A")' -F '((name . "**Agenda**"))'

[Desktop Action inbox]
Name=Work
Exec=/usr/bin/emacsclient -c -e '(tomas/org-agenda-frame "w")' -F '((name . "**Agenda**"))'
```

Note again that with the two actions defined my application launcher will display multiple options for "Agenda": one for each agenda view.

I am placing both of these in the `$HOME/.local/share/applications/` directory.


## See it in action {#see-it-in-action}

With the See me open `org-capture` from my application launcher[^fn:2], capture a todo item, and check it on my agenda:

<video controls>
  <source src="/video/2024-10-04_org-capture_launcher.mp4" type="video/mp4"/>
</video>

[^fn:1]: The full code I will be showing is also available in my [dotfiles GitHub repository](https://github.com/tomasfarias/dotfiles/tree/master), together with my agenda views and capture templates.
[^fn:2]: I am using [fuzzel](https://codeberg.org/dnkl/fuzzel).
