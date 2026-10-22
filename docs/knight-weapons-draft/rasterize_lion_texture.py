"""Create flat, curved lion vector artwork and its native shield UV texture."""
import json
import math
import re
import sys
from pathlib import Path
from PIL import Image, ImageDraw

out=Path(__file__).resolve().parent
data=json.load(sys.stdin)
w,h=data['half_width'],data['half_height']
width=1024
height=round(width*h/w)
factor=3
paint=Image.new('RGB',(width*factor,height*factor),'#142366')
draw=ImageDraw.Draw(paint)
scale=1.18/820
gold='#efd068'
blue='#142366'
svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="{-w} {-h} {w*2} {h*2}">',
     '<title>Flat gold lion sigil — flowing mane and negative-space face</title>',
     f'<g transform="matrix({scale} 0 0 {scale} {-500*scale} {-500*scale})">']

def points_from_path(path):
    tokens=re.findall(r'[MLCQZ]|-?\d+(?:\.\d+)?',path)
    i=0
    points=[]
    current=(0,0)
    while i<len(tokens):
        command=tokens[i]
        i+=1
        if command=='Z':
            break
        count={'M':2,'L':2,'C':6,'Q':4}[command]
        args=[float(x) for x in tokens[i:i+count]]
        i+=count
        if command in ['M','L']:
            current=tuple(args)
            points.append(current)
        else:
            start=current
            end=tuple(args[-2:])
            for step in range(1,65):
                t=step/64
                s=1-t
                if command=='C':
                    p=tuple(s**3*start[j]+3*s*s*t*args[j]+3*s*t*t*args[j+2]+t**3*end[j] for j in range(2))
                else:
                    p=tuple(s*s*start[j]+2*s*t*args[j]+t*t*end[j] for j in range(2))
                points.append(p)
            current=end
    return points

def path(name,commands,color=gold,mirror=False):
    points=points_from_path(commands)
    if mirror:
        points=[(1000-x,y) for x,y in points]
    pixels=[(((x-500)*scale/w+1)*.5*width*factor,((y-500)*scale/h+1)*.5*height*factor) for x,y in points]
    draw.polygon(pixels,fill=color)
    transform=' transform="translate(1000 0) scale(-1 1)"' if mirror else ''
    svg.append(f'<path id="{name}" d="{commands}" fill="{color}"{transform}/>')

# Original artwork informed by the supplied reference's symmetrical, flowing mane.
# Space the numeric pairs so the path remains standard editable SVG.
paired={
 'Crown_V':'M 496 240 C 457 174 442 144 410 126 L 370 133 L 334 99 C 374 82 409 82 436 87 C 454 112 476 151 496 198 Z',
 'Crown_Fan':'M 452 247 C 396 163 355 118 314 103 C 275 116 235 140 212 166 C 294 190 354 219 415 259 Z',
 'Ear':'M 294 245 C 235 199 195 193 173 216 C 155 235 167 260 202 277 L 151 309 C 117 282 103 251 116 215 C 133 158 191 150 238 174 C 270 190 290 211 313 233 Z',
 'Upper_Mane':'M 245 259 C 197 287 141 304 107 339 C 89 360 90 381 99 393 C 139 361 178 336 232 319 C 241 303 244 283 245 259 Z',
 'Outer_Mane':'M 219 335 C 162 368 107 390 96 430 C 85 449 91 500 106 544 L 144 510 C 135 475 142 447 173 424 L 219 389 Z',
 'Middle_Ribbon':'M 216 402 C 250 448 233 486 200 523 C 155 577 169 652 216 693 L 246 722 C 211 663 202 604 239 558 C 274 515 284 469 262 429 Z',
 'Outer_Curl':'M 109 455 C 99 454 102 508 118 571 C 135 638 158 688 195 731 L 196 680 C 164 631 149 584 144 551 C 159 525 191 506 216 486 L 199 453 C 167 478 137 484 109 455 Z',
 'Lower_Ribbon':'M 280 472 C 331 516 331 568 306 612 C 270 671 277 740 317 789 C 332 812 353 830 385 847 C 310 827 261 789 250 742 C 239 695 263 650 278 617 C 295 578 303 549 280 514 Z',
 'Inner_Curl':'M 352 570 C 324 614 309 674 322 725 C 330 763 353 794 380 808 L 449 846 C 398 818 371 777 363 739 C 352 693 369 639 390 600 Z',
}
for name,commands in paired.items():
    path(name+'_Left',commands)
    path(name+'_Right',commands,mirror=True)
path('Face_Outline','M 500 300 C 430 248 370 229 316 215 C 265 290 251 362 269 432 C 290 502 311 563 366 584 C 394 600 432 593 470 569 L 500 545 L 530 569 C 568 593 606 600 634 584 C 689 563 710 502 731 432 C 749 362 735 290 684 215 C 630 229 570 248 500 300 Z')
path('Face_Negative_Space','M 500 333 C 439 285 374 261 337 249 C 295 309 279 365 294 429 C 314 484 336 532 383 548 C 412 560 438 550 473 516 L 500 495 L 527 516 C 562 550 588 560 617 548 C 664 532 686 484 706 429 C 721 365 705 309 663 249 C 626 261 561 285 500 333 Z',blue)
eye='M 327 332 C 362 331 399 337 419 361 C 397 371 365 365 343 346 Z'
path('Eye_Left',eye)
path('Eye_Right',eye,mirror=True)
path('Nose_Bridge','M 419 361 C 438 382 434 438 433 471 C 433 487 463 493 500 494 C 537 493 567 487 567 471 C 566 438 562 382 581 361 C 567 352 557 365 551 388 L 549 461 C 535 472 465 472 451 461 L 449 388 C 443 365 433 352 419 361 Z')
path('Nose_And_Muzzle','M 437 463 C 472 481 528 481 563 463 C 563 486 534 507 517 510 L 517 554 C 540 578 567 590 595 584 L 616 566 C 625 594 601 616 578 618 C 542 618 515 588 500 578 C 485 588 458 618 422 618 C 399 616 375 594 384 566 L 405 584 C 433 590 460 578 483 554 L 483 510 C 466 507 437 486 437 463 Z')
path('Jaw','M 430 610 C 469 629 531 629 570 610 L 562 658 C 528 675 472 675 438 658 Z')
path('Beard','M 409 618 C 379 675 383 739 417 785 C 437 812 461 842 500 882 C 539 842 563 812 583 785 C 617 739 621 675 591 618 L 564 630 C 586 687 573 744 550 778 L 500 834 L 450 778 C 427 744 414 687 436 630 Z')
path('Chin_Triangle','M 472 713 L 528 713 L 500 759 Z')
svg.append('</g>')
svg.append('</svg>')
(out/'lion-sigil.svg').write_text('\n'.join(svg)+'\n')
paint.resize((width,height),Image.Resampling.LANCZOS).save(out/'lion-shield-paint.png')
print('FLAT_LION_TEXTURE_CREATED',width,height)
