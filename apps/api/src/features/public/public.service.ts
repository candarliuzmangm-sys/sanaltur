import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PropertyStatus } from '@prisma/client';

import { PrismaService } from '../../shared/prisma/prisma.service';
import { normalizeStoredGraph, mapTourGraphToPublic } from '../../shared/tour/tour-mapper';
import {
  buildShareUrls,
  resolvePublicMediaUrl,
} from '../../shared/utils/public-url.util';

@Injectable()
export class PublicService {
  private readonly apiPublicUrl: string;
  private readonly publicWebUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.apiPublicUrl = config.get(
      'API_PUBLIC_URL',
      'http://localhost:3001',
    );
    this.publicWebUrl = config.get(
      'PUBLIC_WEB_URL',
      'http://localhost:3000',
    );
  }

  private media(url: string | null | undefined) {
    return resolvePublicMediaUrl(url, this.apiPublicUrl);
  }

  async getPropertyBySlug(slug: string) {
    const property = await this.prisma.property.findUnique({
      where: { publicSlug: slug },
      include: {
        tour: true,
        rooms: {
          include: { media: { orderBy: { createdAt: 'asc' } } },
          orderBy: { order: 'asc' },
        },
      },
    });

    if (!property || property.status !== PropertyStatus.PUBLISHED) {
      throw new NotFoundException('Property not found or not published');
    }

    const tourSlug =
      property.tour?.slug ?? property.publicSlug ?? undefined;

    return {
      slug: property.publicSlug,
      tourSlug,
      title: property.title,
      address: property.address,
      description: property.description,
      coverImageUrl: this.media(property.coverImageUrl),
      rooms: property.rooms.map((room) => ({
        id: room.id,
        name: room.name,
        type: room.aiDetectedType ?? room.type,
        order: room.order,
        media: room.media.map((m) => ({
          id: m.id,
          url: this.media(m.url)!,
          mimeType: m.mimeType,
        })),
      })),
    };
  }

  async getTourBySlug(slug: string) {
    const tour = await this.prisma.tour.findUnique({
      where: { slug },
      include: {
        property: {
          include: {
            floorplan: true,
            rooms: {
              include: { media: { take: 1, orderBy: { createdAt: 'desc' } } },
              orderBy: { order: 'asc' },
            },
          },
        },
      },
    });

    if (!tour || tour.property.status !== PropertyStatus.PUBLISHED) {
      throw new NotFoundException('Tour not found');
    }

    const graph = normalizeStoredGraph(tour.graphJson);
    if (!graph) {
      throw new NotFoundException('Tour graph is empty');
    }

    const fpUrl =
      tour.property.floorplan?.svgUrl ?? tour.property.floorplan?.pngUrl;
    const publicSlug = tour.property.publicSlug ?? tour.slug;
    const share = buildShareUrls(this.publicWebUrl, publicSlug, tour.slug);

    return mapTourGraphToPublic(
      graph,
      {
        slug: tour.slug,
        title: tour.property.title,
        description: tour.property.description,
        coverImageUrl: tour.property.coverImageUrl,
        floorplanUrl: fpUrl,
        shareUrl: share.tour ?? undefined,
      },
      (url) => this.media(url),
    );
  }
}
