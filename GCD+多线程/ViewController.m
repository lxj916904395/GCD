//
//  ViewController.m
//  GCD+多线程
//
//  Created by zhongding on 2018/10/22.
//

#import "ViewController.h"

@interface ViewController ()
@property(strong ,nonatomic) dispatch_source_t source;
@property(strong ,nonatomic) dispatch_queue_t sourcequeue;

@property(assign ,nonatomic) NSUInteger total;
@property(assign ,nonatomic) BOOL isruning;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self barrier];
    
}

- (void)mainQueueSync{
    //相互等待造成死锁
    //1的打印需要等待dispatch_sync执行完，
    //dispatch_sync执行完成需要等待1打印完成
    //解决：dispatch_sync 改为dispatch_async
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"1");
    });
    NSLog(@"2");
}

- (void)whileAsync{
    
    __block int  a = 0;
    while (a<5) {
        /*
         由于是异步并发，while循坏不会等block执行完就开始下一次循坏
         下一次循坏开始时，可能其他的block还没执行完，a的值还没++，
         导致打印的a未变
         解决：把while循坏放大async里面执行
         */
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
           NSLog(@"%@===%d",[NSThread currentThread],a);
            a++;
        });
    }
//    NSLog(@"%@===%d",[NSThread currentThread],a);

}

#pragma mark ***************** 栅栏函数;
- (void)barrier{
    dispatch_queue_t queue = dispatch_queue_create("xs", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        NSLog(@"----1-----%@", [NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        NSLog(@"----2-----%@", [NSThread currentThread]);
    });
    
    //上面的任务执行完，才会执行下面的任务，前提是任务必须在同一个 dispatch_queue_t 中
    dispatch_barrier_async(queue, ^{
        NSLog(@"----barrier-----%@", [NSThread currentThread]);
    });
    
    dispatch_async(queue, ^{
        NSLog(@"----3-----%@", [NSThread currentThread]);
    });
    dispatch_async(queue, ^{
        NSLog(@"----4-----%@", [NSThread currentThread]);
    });
}


#pragma mark ***************** 调度组;

- (void)groupAsync{
    //调度组
    dispatch_group_t grouop = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    
    dispatch_group_async(grouop, queue, ^{
//        sleep(2);
        NSLog(@"1");
    });
    
    dispatch_group_async(grouop, queue, ^{
        NSLog(@"2");
    });
    
//    long timeout = dispatch_group_wait(grouop, 1);
//    if (timeout) {
    //上面任务完成后，才可以继续执行下面的任务
        dispatch_group_notify(grouop, queue, ^{
             NSLog(@"3");
        });
//    }
}

- (void)groupAsync2{
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    dispatch_group_t group = dispatch_group_create();
    
    //dispatch_group_enter 比 dispatch_group_leave 少， 会崩溃
   
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        NSLog(@"1");
        dispatch_group_leave(group);

    });
    
    dispatch_group_enter(group);
    dispatch_async(queue, ^{
        NSLog(@"2");
        dispatch_group_leave(group);
    });
    
    //下面的、任务 dispatch_group_enter 与 dispatch_group_leave 成对出现才会执行
    //上面的任务执行完才会执行
    dispatch_group_notify(group, queue, ^{
        NSLog(@"3");
    });
}

#pragma mark ***************** 信号量
- (void)semaphore{
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    //1:同一时间任务的最大并发数
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(2);
    
    /*
        最大并发数为1时,dispatch_semaphore_wait 、dispatch_semaphore_signal必须成对出现，后续任务才会被执行，两者成对出现可理解为同步串行
     */
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_async(queue, ^{
        NSLog(@"%@==开始1任务",[NSThread currentThread]);
//        sleep(2);
        NSLog(@"结束1任务");
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_async(queue, ^{
        NSLog(@"%@==开始2任务",[NSThread currentThread]);
        sleep(1);
        NSLog(@"结束2任务");
        dispatch_semaphore_signal(semaphore);
    });
    
    /*
        上面只有 dispatch_semaphore_wait，后续任务不会被执行
     */
    
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_async(queue, ^{
        NSLog(@"%@==开始3任务",[NSThread currentThread]);
        NSLog(@"结束3任务");
        dispatch_semaphore_signal(semaphore);
    });
}


#pragma mark ***************** source;

- (void)sourceQueue{
    self.sourcequeue = dispatch_queue_create("lxj", 0);
    self.source = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(_source, ^{
        NSUInteger value = dispatch_source_get_data(self.source);
        self.total += value;
        NSLog(@"%zd",self.total);
    });
    
    dispatch_resume(self.source);
    
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    self.isruning = !self.isruning;
    if (self.isruning) {
        dispatch_suspend(self.sourcequeue);
        dispatch_suspend(self.source);
    }else{
        dispatch_resume(self.sourcequeue);
        dispatch_resume(self.source);

        //发送数据,触发 dispatch_source_set_event_handler
        dispatch_source_merge_data(_source, 1);
    }
}

@end
