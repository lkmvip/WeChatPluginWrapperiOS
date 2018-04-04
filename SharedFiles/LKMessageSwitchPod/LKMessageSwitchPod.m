//  weibo: http://weibo.com/xiaoqing28
//  blog:  http://www.alonemonkey.com
//
//  LKMessageSwitchPod.m
//  LKMessageSwitchPod
//
//  Created by sherlock on 2017/10/12.
//  Copyright (c) 2017年 sherlock. All rights reserved.
//

#import "LKMessageSwitchPod.h"
#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>
#import "WeChatHeader.h"
//#import "LKWeChatHeader.h"
#import "UINavigationController+FDFullscreenPopGesture.h"


static NSString * const LKNewMessageNotification = @"LKNewMessageNotification";
static NSString * const LKDidEnterChatNotification = @"LKDidEnterChatNotification";
static NSString * const LKChatKey = @"LKChatKey";
static NSString * const LKContentKey = @"LKContentKey";


@interface LKNotificationView : UIVisualEffectView
@property (nonatomic, strong) NSString *chat;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UILabel *textLabel;
@property (nonatomic,  weak ) id observer;
@end
@implementation LKNotificationView

- (void)dealloc
{

}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]])
    {
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:17];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor clearColor];
        [self addSubview:label];
        self.textLabel = label;

        self.frame = frame;
        self.layer.cornerRadius = 10;
        self.clipsToBounds = YES;

        __weak typeof(self) weakSelf = self;
        self.observer = [[NSNotificationCenter defaultCenter] addObserverForName:LKDidEnterChatNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
        {
            if ([weakSelf.chat isEqual: note.userInfo[LKChatKey]]) {
                [weakSelf clear];
            }
        }];
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];

    self.textLabel.frame = CGRectMake(10, 0, frame.size.width - 20, frame.size.height);
}

- (void)setText:(NSString *)text
{
    if (![_text isEqualToString:text]) {
        _text = text;

        self.textLabel.text = text;
    }
}

- (void)clear
{
    [[NSNotificationCenter defaultCenter] removeObserver:self.observer];
    [self removeFromSuperview];
}

@end

void ShowAnimation(UIView *view)
{
    CGRect frame = view.frame;
    view.bottom = view.top;
    [UIView animateWithDuration:.2 animations:^{
        view.frame = frame;
    }];
}

void DismissAnimation(LKNotificationView *view, UISwipeGestureRecognizerDirection direction)
{
    [UIView animateWithDuration:.2 animations:^{
        switch (direction) {
            case UISwipeGestureRecognizerDirectionUp:
                view.bottom = view.top;
                break;
            case UISwipeGestureRecognizerDirectionLeft:
                view.right = view.left;
                break;
            case UISwipeGestureRecognizerDirectionRight:
                view.left = view.right;
                break;
            default:
                break;
        }
    } completion:^(BOOL finished) {
        [view clear];
    }];
}

// hook 消息接收类
CHDeclareClass(CMessageMgr)
CHOptimizedMethod2(self, void, CMessageMgr, AsyncOnAddMsg, NSString *, msg, MsgWrap, CMessageWrap *, wrap)
{
    if (wrap.m_nsPushContent.length) {

        CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("CContactMgr") class]];

        CContact *fromUsrContact = [contactMgr getContactByName:wrap.m_nsFromUsr];
        NSMutableString *text = [NSMutableString stringWithString:@""];

        if (fromUsrContact.isChatroom) {
            CContact *realChatUsrContact = [contactMgr getContactByName:wrap.m_nsRealChatUsr];
            [text appendFormat:@"[%@] ", [fromUsrContact getContactDisplayName]];
            [text appendFormat:@"%@:%@", [fromUsrContact getChatRoomMemberDisplayName:realChatUsrContact], wrap.m_nsContent];
        } else {
            [text appendFormat:@"%@:%@", [fromUsrContact getContactDisplayName], wrap.m_nsContent];
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:LKNewMessageNotification object:nil userInfo:@{LKChatKey : msg, LKContentKey : text}];
    }

    CHSuper2(CMessageMgr, AsyncOnAddMsg, msg, MsgWrap, wrap);
}

//聊天基本页面
CHDeclareClass(BaseMsgContentViewController)
CHOptimizedMethod1(self, void, BaseMsgContentViewController, viewWillAppear, BOOL, flag)
{
    CHSuper1(BaseMsgContentViewController, viewWillAppear, flag);

    [[NSNotificationCenter defaultCenter] postNotificationName:LKDidEnterChatNotification object:self userInfo:@{LKChatKey : [self getCurrentChatName] ?: @""}];
}

// hook MMUIViewController基类
CHDeclareClass(MMUIViewController)
CHDeclareMethod1(void, MMUIViewController, messageCallBack, NSNotification *, note)
{
    /*
     * case 1 不是聊天界面
     * case 2 是聊天界面，跟当前界面不是同一界面
     */
    if (![self isKindOfClass:objc_getClass("BaseMsgContentViewController")] ||
        ![[(BaseMsgContentViewController *)self getCurrentChatName] isEqualToString:note.userInfo[LKChatKey]])
    {
        LKNotificationView *view = [[LKNotificationView alloc] initWithFrame:CGRectMake(0, 64, self.view.width, 44)];
        view.text = note.userInfo[LKContentKey];
        view.chat = note.userInfo[LKChatKey];

        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
        swipe.direction = UISwipeGestureRecognizerDirectionUp;
        swipe.numberOfTouchesRequired = 1;
        [view addGestureRecognizer:swipe];

        swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
        swipe.direction = UISwipeGestureRecognizerDirectionLeft;
        swipe.numberOfTouchesRequired = 1;
        [view addGestureRecognizer:swipe];

        swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
        swipe.direction = UISwipeGestureRecognizerDirectionRight;
        swipe.numberOfTouchesRequired = 1;
        [view addGestureRecognizer:swipe];
        [self.navigationController.fd_fullscreenPopGestureRecognizer requireGestureRecognizerToFail:swipe];

        [view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backToMsgContentViewController:)]];
        [self.view addSubview:view];

        ShowAnimation(view);
        // 后台收消息不做自动隐藏处理，防止当前信息看到一半被打断锁屏
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DismissAnimation(view, UISwipeGestureRecognizerDirectionUp);
            });
        }
    }
}

CHDeclareMethod1(void, MMUIViewController, backToMsgContentViewController, UITapGestureRecognizer *, sender)
{
    LKNotificationView *view = (LKNotificationView *)sender.view;
    [view clear];

    MMServiceCenter* serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
    CContactMgr *contactMgr = [serviceCenter getService:[objc_getClass("CContactMgr") class]];
    CContact *contact = [contactMgr getContactByName:view.chat];
    
    MMMsgLogicManager *logicManager = [serviceCenter getService:[objc_getClass("MMMsgLogicManager") class]];
    [logicManager PushOtherBaseMsgControllerByContact:contact navigationController:[[objc_getClass("CAppViewControllerManager") topViewControllerOfMainWindow] navigationController] animated:YES];
}

CHDeclareMethod1(void, MMUIViewController, handleSwipes, UISwipeGestureRecognizer *, sender)
{
    DismissAnimation((LKNotificationView *)sender.view, sender.direction);
}

CHOptimizedMethod1(self, void, MMUIViewController, viewWillAppear, BOOL, flag)
{
    NSString *currentVCClassName = @(object_getClassName(self));

    if (![currentVCClassName isEqual: @"NSKVONotifying_NewMainFrameViewController"]
        &&![currentVCClassName isEqual:@"NSKVONotifying_WCCommentListViewController"]
        && ![currentVCClassName isEqual:@"NSKVONotifying_SayHelloViewController"])
    { //对新好友提示页面和朋友圈评论列表页面设置通知,会导致页面不被释放,消息重复提示的bug
        [[NSNotificationCenter defaultCenter] removeObserver:self name:LKNewMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageCallBack:) name:LKNewMessageNotification object:nil];
        
    }
    CHSuper1(MMUIViewController, viewWillAppear, flag);
}

CHOptimizedMethod1(self, void, MMUIViewController, viewWillDisappear, BOOL, flag)
{
    NSString * currentVCClassName = @(object_getClassName(self));

    if (![currentVCClassName isEqual: @"NSKVONotifying_NewMainFrameViewController"]
        &&![currentVCClassName isEqual:@"NSKVONotifying_WCCommentListViewController"]
        && ![currentVCClassName isEqual:@"NSKVONotifying_SayHelloViewController"])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:LKNewMessageNotification object:nil];
    }
    CHSuper1(MMUIViewController, viewWillDisappear, flag);
}

CHConstructor{

    CHLoadLateClass(CMessageMgr);
    CHClassHook2(CMessageMgr, AsyncOnAddMsg, MsgWrap);

    CHLoadLateClass(MMUIViewController);
    CHClassHook1(MMUIViewController, viewWillAppear);
    CHClassHook1(MMUIViewController, viewWillDisappear);

    CHLoadLateClass(BaseMsgContentViewController);
    CHClassHook1(BaseMsgContentViewController, viewWillAppear);
}
