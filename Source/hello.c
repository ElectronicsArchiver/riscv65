#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <fcntl.h>
#include <unistd.h>

int
main(void)
{
    static const char path[] = "/dir.1/dir.2/test.txt";
    int x;
    int fd = open(path, O_RDONLY, 0);
    printf("len=%u open returns: %d\n", (unsigned)strlen(path), fd);

    // Seek forward, from end
    long pos = lseek(fd, -60000, SEEK_END);
    x = errno;
    printf("pos=%ld\n", pos);
    errno = x;
    if (pos == -1) {
        perror("lseek");
    }

    char buf[20];
    ssize_t len = read(fd, buf, sizeof(buf));
    printf("Sample: %.*s\n", (int)len, buf);

    // Seek backward, from beginning
    pos = lseek(fd, 10000, SEEK_SET);
    x = errno;
    printf("pos=%ld\n", pos);
    errno = x;
    if (pos == -1) {
        perror("lseek");
    }

    len = read(fd, buf, sizeof(buf));
    printf("Sample: %.*s\n", (int)len, buf);

    // Seek forward, from current
    pos = lseek(fd, 10000, SEEK_CUR);
    x = errno;
    printf("pos=%ld\n", pos);
    errno = x;
    if (pos == -1) {
        perror("lseek");
    }

    len = read(fd, buf, sizeof(buf));
    printf("Sample: %.*s\n", (int)len, buf);

    int fd2;
    static const char path2[] = "/dir.1/dir.2/test-2.txt";
    fd2 = open(path2, O_RDWR | O_CREAT, 0644);
    x = errno;
    printf("fd2=%d\n", fd2);
    errno = x;
    if (fd2 < 0) {
        perror(path2);
    }
    close(fd2);

    // This is supposed to fail
    fd2 = open(path, O_RDWR | O_CREAT | O_EXCL, 0644);
    x = errno;
    printf("fd2=%d\n", fd2);
    errno = x;
    if (fd2 < 0) {
        perror(path);
    }
    close(fd2);

    // This should also fail: the file is already open
    fd2 = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    x = errno;
    printf("fd2=%d\n", fd2);
    errno = x;
    if (fd2 < 0) {
        perror(path);
    }
    close(fd2);

    // This should succeed
    fd2 = open(path, O_RDONLY, 0);
    x = errno;
    printf("fd2=%d\n", fd2);
    errno = x;
    if (fd2 < 0) {
        perror(path);
    }
    close(fd2);

    close(fd);

    // This should succeed, and truncate the file
    fd2 = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    x = errno;
    printf("fd2=%d\n", fd2);
    errno = x;
    if (fd2 < 0) {
        perror(path);
    }
    close(fd2);

#if 0
    if (fd >= 0) {
        char buf[1024];
        ssize_t len;
        long count = 0;

        time_t t1 = time(NULL);
        do {
            len = read(fd, buf, sizeof(buf));
            if (len < 0) {
                perror(path);
                break;
            }
            //write(1, buf, len);
            count += len;
        } while (len != 0);
        printf("Read %ld bytes\n", count);
        time_t t2 = time(NULL);
        printf("%ld seconds elapsed\n", (long)(t2-t1));
    } else {
        perror(path);
    }
#endif

    return 0;
}
