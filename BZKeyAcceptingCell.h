@protocol BZKeyAcceptingCell <NSObject>

- (BOOL)keyDown:(NSEvent *)event;
- (BOOL)keyUp:(NSEvent *)event;

@end
