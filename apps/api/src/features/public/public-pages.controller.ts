import { Controller, Get, Param, Res } from '@nestjs/common';
import { Response } from 'express';

/** Sanal tur paylaşım linki: /tour/:slug → viewer */
@Controller()
export class PublicPagesController {
  @Get('tour/:slug')
  redirectTour(@Param('slug') slug: string, @Res() res: Response) {
    res.redirect(302, `/viewer.html?slug=${encodeURIComponent(slug)}`);
  }
}
