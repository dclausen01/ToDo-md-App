---

kanban-plugin: board
sticker: 1f4b9
banner:
color:

---

## **Doing**

- [ ] **Bold card with tag and date**
	#Work @{2026-06-24}
- [ ] Plain card without bold
	Some description line.
	#Home
- [ ] **Card with subtasks**
	- [x] First subtask done
	- [ ] Second subtask open
	#Project
- [ ] **Card with internal links**
	- [[Some Note]]
	- [[Folder/Other Note_abc123]]
	![[Embedded Note]]
	#Work @{2026-06-26}


## to do <--

- [ ] **Card with block id** ^a1b2c3
	![[Big Project Note]]
	#Work
- [ ] [[Link only card title]]
	_metadata italic_ #Home
- [ ] **Card with url**
	https://example.org/path?x=1#y
	[label](https://example.org/other)
	#Work @{2026-07-01} @@{09:15}
- [ ] **Card with separators**
	- [x] Step one
	- [x] Step two

	***
	- [ ] Final step
	@{2026-03-13}

	#Project March


## --> done

- [ ] **Duplicate card**
	#Home
- [ ] **Duplicate card**
	#Home
- [ ] **Messy concatenated line**
	#Work- [ ] not a real card here
- [x] **Completed top-level card**
	#Project @{2026-01-19} @@@{10:00}


%% kanban:settings
```
{"kanban-plugin":"board","hide-tags-in-title":true,"lane-width":285,"show-checkboxes":false,"list-collapse":[false,null,false]}
```
%%
