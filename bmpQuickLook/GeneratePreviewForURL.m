#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import <Cocoa/Cocoa.h>

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
    @autoreleasepool{
        
        NSData *bmpData = [NSData dataWithContentsOfURL:(__bridge NSURL*)url];
        NSUInteger len = [bmpData length];
        unsigned char *bytePtr = (unsigned char *)[bmpData bytes];
        UInt32 bitmapOffset = 0;
        UInt32 headerSize = 0;
        
        if (len < 64) {
            NSLog(@"The file size is too small.");
        }else if (!((bytePtr[0]== 'B')&&(bytePtr[1]== 'M'))) {
            NSLog(@"Header didnot start 'BM'");
        }else {
            bitmapOffset = *((UInt32 *)(bytePtr+0x0a));
            headerSize = *((UInt32 *)(bytePtr+0x0e));
        }
        
        UInt32 width = 0;
        UInt32 height = 0;
        UInt16 planes = 0; /* Number of color planes */
        UInt16 bitsPerPixel = 0;    /* Number of bits per pixel */
        /* Fields added for Windows 3.x follow this line */
        UInt32 compression = 0;     /* Compression methods used */
        UInt32 sizeOfBitmap = 0;    /* Size of bitmap in bytes */
        UInt32 horzResolution = 0;  /* Horizontal resolution in pixels per meter */
        UInt32 vertResolution = 0;  /* Vertical resolution in pixels per meter */
        UInt32 colorsUsed = 0;      /* Number of colors in the image */
        UInt32 colorsImportant= 0; /* Minimum number of important colors */
        
        //NSLog(@"len %lu",(unsigned long)len);
        //NSLog(@"headerSize:%d",headerSize);
        
        if (headerSize == 40) { //Windows V3
            width = *((UInt32 *)(bytePtr+0x12));
            height = *((UInt32 *)(bytePtr+0x16));
            planes = *((UInt16 *)(bytePtr+0x1a));
            bitsPerPixel = *((UInt16 *)(bytePtr+0x1c));
            compression = *((UInt32 *)(bytePtr+0x1e));
            sizeOfBitmap = *((UInt32 *)(bytePtr+0x22));
            horzResolution = *((UInt32 *)(bytePtr+0x26));
            vertResolution = *((UInt32 *)(bytePtr+0x2a));
            colorsUsed = *((UInt32 *)(bytePtr+0x2e));
            colorsImportant = *((UInt32 *)(bytePtr+0x32));
            
            size_t bitsPerComponent = 8;
            size_t bytesPerRow = (bitsPerPixel * width)/8;
            size_t bufferLength = bytesPerRow * height;
            
            // bytesPerRow is the multiple of 4.
            if ((bytesPerRow % 4) !=0) {
                bytesPerRow += 4-(bytesPerRow % 4);
            }
            
            CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
            CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
            CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
            if (bitsPerPixel == 24) {
                bitmapInfo = kCGBitmapByteOrderDefault;;
                
                // BGR->RGB
                for (int y=0;y<height;y++) {
                    for (int x=0;x<width;x++) {
                        NSUInteger offset = bitmapOffset + y*bytesPerRow + x*3;

                        unsigned char blue = bytePtr[offset];
                        bytePtr[offset] = bytePtr[offset+2];
                        bytePtr[offset+2] = blue;
                    }
                }
            }
            
            CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bytePtr+bitmapOffset, bufferLength, NULL);

            //NSLog(@"width:%d height:%d bufferLength:%zd",width,height,bufferLength);
            //NSLog(@"bytesPerRow:%zd bitsPerPixel:%zd",bytesPerRow,bitsPerPixel);
            //NSLog(@"horzResolution:%zd vertResolution:%zd",horzResolution,vertResolution);
            //NSLog(@"colorsUsed:%zd colorsImportant:%zd",colorsUsed,colorsImportant);
            
            CGImageRef imageRef = CGImageCreate(width,
                                            height,
                                            bitsPerComponent,
                                            bitsPerPixel,
                                            bytesPerRow,
                                            colorSpaceRef,
                                            bitmapInfo,
                                            provider,   // data provider
                                            NULL,       // decode
                                            NO,        // should interpolate
                                            renderingIntent);
            
            // Preview will be drawn in a vectorized context
            NSSize canvasSize = NSMakeSize(width, height);
            CGRect imageRect = CGRectMake(0.0f, 0.0f, width, height);
            CGContextRef cgContext = QLPreviewRequestCreateContext(preview, *(CGSize *)&canvasSize, true, NULL);
            if(cgContext) {
                CGContextTranslateCTM(cgContext, 0, height);
                CGContextScaleCTM(cgContext, 1.0, -1.0);
                
                CGContextDrawImage(cgContext, imageRect , imageRef);
                QLPreviewRequestFlushContext(preview, cgContext);
                CFRelease(cgContext);
            }
            CGImageRelease(imageRef);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(colorSpaceRef);
        }
    }
    return noErr;
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
}

