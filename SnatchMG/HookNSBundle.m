//
//  HookNSBundle.m
//  MeloNX
//
//  Created by Stossy11 on 24/10/2025.
//

#import "SnatchMG-Swift.h"

__attribute__((constructor))
void EarlyInitConstructor(void) {
    [EarlyInit entryPoint]; 
}
