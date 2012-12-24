#include "config.h"

#if defined(HAVE_LOCKF)

#include <unistd.h>
#include <errno.h>

/*  Emulate flock() with lockf() or fcntl().  This is just to increase
    portability of scripts.  The calls might not be completely
    interchangeable.  What's really needed is a good file
    locking module.
*/

# ifndef F_ULOCK
#  define F_ULOCK	0	/* Unlock a previously locked region */
# endif
# ifndef F_LOCK
#  define F_LOCK	1	/* Lock a region for exclusive use */
# endif
# ifndef F_TLOCK
#  define F_TLOCK	2	/* Test and lock a region for exclusive use */
# endif
# ifndef F_TEST
#  define F_TEST	3	/* Test a region for other processes locks */
# endif

/* These are the flock() constants.  Since this sytems doesn't have
   flock(), the values of the constants are probably not available.
*/
# ifndef LOCK_SH
#  define LOCK_SH 1
# endif
# ifndef LOCK_EX
#  define LOCK_EX 2
# endif
# ifndef LOCK_NB
#  define LOCK_NB 4
# endif
# ifndef LOCK_UN
#  define LOCK_UN 8
# endif

int
flock(fd, operation)
    int fd;
    int operation;
{
    int i;
    switch (operation) {

	/* LOCK_SH - get a shared lock */
      case LOCK_SH:
	/* LOCK_EX - get an exclusive lock */
      case LOCK_EX:
	i = lockf (fd, F_LOCK, 0);
	break;

	/* LOCK_SH|LOCK_NB - get a non-blocking shared lock */
      case LOCK_SH|LOCK_NB:
	/* LOCK_EX|LOCK_NB - get a non-blocking exclusive lock */
      case LOCK_EX|LOCK_NB:
	i = lockf (fd, F_TLOCK, 0);
	if (i == -1)
	    if ((errno == EAGAIN) || (errno == EACCES))
		errno = EWOULDBLOCK;
	break;

	/* LOCK_UN - unlock */
      case LOCK_UN:
	i = lockf (fd, F_ULOCK, 0);
	break;

	/* Default - can't decipher operation */
      default:
	i = -1;
	errno = EINVAL;
	break;
    }
    return i;
}
#else
int
flock(fd, operation)
    int fd;
    int operation;
{
    rb_notimplement();
    return -1;
}
#endif
